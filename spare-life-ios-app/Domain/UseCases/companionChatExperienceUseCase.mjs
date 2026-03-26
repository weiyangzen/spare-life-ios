import {
  buildMessagesHomeRoute,
  buildConversationRoute,
  buildCounterpartParticipantKey,
  buildDefaultDirectParticipants,
  buildDefaultGroupParticipants,
  buildGroupParticipantKey,
  buildSelfParticipantKey,
  collectMaskTerms,
  deriveRelationshipLevelFromWarmth,
  resolveMaskOpenness,
  resolveMaskTone,
  resolveRitualKind
} from '../Models/companionContracts.mjs';
import {
  clipText
} from '../Models/masterContracts.mjs';
import {
  isoNow,
  sanitizeText,
  stableId,
  uniqueStrings
} from '../Models/sceneContracts.mjs';
import {
  buildLayeredMemorySnapshots,
  recallRelevantMemorySnapshots
} from '../../LocalBackend/ConversationMemory/companionRecallService.mjs';
import {
  buildCompanionWorkspaceSeed,
  buildConversationContext,
  buildGroupSummary,
  buildGroupVote,
  buildRecentChatCards,
  buildRelationshipSnapshot,
  buildRitualRecord,
  composeCounterpartAgentReply,
  composeCounterpartReply,
  composeSelfAgentAssist,
  computeWarmthDelta,
  scoreMessageSignal,
  tallyGroupVote
} from '../../Services/CompanionChat/companionChatService.mjs';

function isOwnerParticipantKey(participantKey) {
  return [buildSelfParticipantKey('human'), buildSelfParticipantKey('agent')].includes(participantKey);
}

function directConversationId(userId, contactId) {
  return stableId('companion-conversation', userId, contactId);
}

function groupConversationId(userId, groupId) {
  return stableId('companion-conversation', userId, groupId);
}

function relationshipId(userId, contactId) {
  return stableId('companion-relationship', userId, contactId);
}

function groupMemberRows(group, contacts) {
  return [
    {
      memberKey: 'self',
      role: 'human',
      displayName: '我',
      permissions: {
        canPost: true
      }
    },
    ...contacts.map((contact) => ({
      memberKey: contact.id,
      role: 'human',
      displayName: contact.displayName,
      contactId: contact.id,
      permissions: {
        canPost: true
      }
    })),
    {
      memberKey: `${group.id}-tool`,
      role: 'tool_agent',
      displayName: group.toolAgentName,
      permissions: {
        canPost: true,
        canSummarize: true,
        canLaunchVote: true
      }
    }
  ];
}

export class CompanionChatExperienceUseCase {
  constructor({ repository }) {
    this.repository = repository;
  }

  ensureWorkspace(userId) {
    if (this.repository.countContactsForOwner(userId) > 0) {
      return;
    }

    const nowIso = isoNow();
    const seed = buildCompanionWorkspaceSeed({
      userId,
      nowIso
    });
    const contactById = new Map(seed.contacts.map((contact) => [contact.id, contact]));

    this.repository.withTransaction(() => {
      for (const contact of seed.contacts) {
        this.repository.upsertContact(contact);
        const maskId = stableId('companion-mask', contact.id, 'default');
        this.repository.insertMask({
          id: maskId,
          contactId: contact.id,
          tone: contact.defaultMask.tone,
          openness: contact.defaultMask.openness,
          boundaryTags: contact.defaultMask.boundaryTags,
          signature: contact.defaultMask.signature,
          overrideRules: ['default_seed'],
          isActive: true,
          createdAt: contact.createdAt,
          updatedAt: contact.updatedAt
        });
        this.repository.recordMaskHistory({
          contactId: contact.id,
          maskId,
          changeSummary: '初始化默认对人面具',
          diff: {
            to: collectMaskTerms(contact.defaultMask)
          },
          createdAt: contact.createdAt
        });
      }

      for (const group of seed.groups) {
        this.repository.upsertGroup(group);
        const groupContacts = group.memberContactIds.map((contactId) => contactById.get(contactId)).filter(Boolean);
        this.repository.replaceGroupMembers(group.id, groupMemberRows(group, groupContacts), nowIso);
      }

      for (const directSeed of seed.directSeeds) {
        const contact = contactById.get(directSeed.contactId);
        const conversationId = directConversationId(userId, contact.id);
        const route = buildConversationRoute({
          conversationId,
          kind: 'direct',
          contactId: contact.id
        });
        const unreadCount = directSeed.messages.filter((message) => message.unreadForOwner).length;
        const lastMessage = directSeed.messages.at(-1);

        this.repository.upsertConversation({
          id: conversationId,
          ownerUserId: userId,
          kind: 'direct',
          title: contact.displayName,
          contactId: contact.id,
          unreadCount,
          lastMessagePreview: lastMessage?.content ?? null,
          lastMessageAt: lastMessage?.createdAt ?? nowIso,
          lastOpenedAt: directSeed.messages[0]?.createdAt ?? nowIso,
          route,
          createdAt: directSeed.messages[0]?.createdAt ?? nowIso,
          updatedAt: lastMessage?.createdAt ?? nowIso
        });
        this.repository.replaceConversationParticipants(
          conversationId,
          buildDefaultDirectParticipants(contact),
          nowIso
        );
        const relationship = this.repository.upsertRelationship({
          id: relationshipId(userId, contact.id),
          ownerUserId: userId,
          contactId: contact.id,
          conversationId,
          level: deriveRelationshipLevelFromWarmth(directSeed.warmthScore),
          warmthScore: directSeed.warmthScore,
          latestSummary: directSeed.latestSummary,
          memorialCard: directSeed.memorialCard,
          createdAt: directSeed.messages[0]?.createdAt ?? nowIso,
          updatedAt: lastMessage?.createdAt ?? nowIso
        });

        const insertedMessages = directSeed.messages.map((message) =>
          this.repository.appendMessage({
            conversationId,
            actorKey: message.actorKey,
            actorRole: message.actorRole,
            channelKind: message.channelKind,
            content: message.content,
            metadata: {
              seeded: true
            },
            unreadForOwner: message.unreadForOwner,
            createdAt: message.createdAt
          })
        );

        const selfMessage = insertedMessages.find((message) => message.actorRole === 'self_human');
        const counterpartMessage = [...insertedMessages].reverse().find((message) =>
          ['counterpart_human', 'counterpart_agent'].includes(message.actorRole)
        );
        if (selfMessage && counterpartMessage) {
          this.repository.saveMemorySnapshots(
            buildLayeredMemorySnapshots({
              userId,
              contactId: contact.id,
              counterpartName: contact.displayName,
              conversationId,
              userMessage: selfMessage.content,
              counterpartMessage: counterpartMessage.content,
              relationship,
              sourceMessageIds: [selfMessage.id, counterpartMessage.id],
              nowIso: counterpartMessage.createdAt
            })
          );
        }
      }

      for (const groupSeed of seed.groupSeeds) {
        const group = seed.groups.find((item) => item.id === groupSeed.groupId);
        const conversationId = groupConversationId(userId, group.id);
        const participants = [
          {
            participantKey: buildSelfParticipantKey('human'),
            role: 'self_human',
            displayName: '我',
            permissions: {
              canPost: true,
              canModerate: true
            }
          },
          ...buildDefaultGroupParticipants(
            group,
            group.memberContactIds.map((contactId) => contactById.get(contactId)).filter(Boolean)
          )
        ];
        const unreadCount = groupSeed.messages.filter((message) => message.unreadForOwner).length;
        const lastMessage = groupSeed.messages.at(-1);
        this.repository.upsertConversation({
          id: conversationId,
          ownerUserId: userId,
          kind: 'group',
          title: group.title,
          groupId: group.id,
          unreadCount,
          lastMessagePreview: lastMessage?.content ?? null,
          lastMessageAt: lastMessage?.createdAt ?? nowIso,
          lastOpenedAt: groupSeed.messages[0]?.createdAt ?? nowIso,
          route: group.route,
          createdAt: groupSeed.messages[0]?.createdAt ?? nowIso,
          updatedAt: lastMessage?.createdAt ?? nowIso
        });
        this.repository.replaceConversationParticipants(conversationId, participants, nowIso);
        for (const message of groupSeed.messages) {
          this.repository.appendMessage({
            conversationId,
            actorKey: message.actorKey,
            actorRole: message.actorRole,
            channelKind: message.channelKind,
            content: message.content,
            metadata: {
              seeded: true
            },
            signalScore: message.signalScore ?? 100,
            suppressed: (message.signalScore ?? 100) < group.noiseThreshold,
            unreadForOwner: message.unreadForOwner,
            createdAt: message.createdAt
          });
        }
      }
    });
  }

  openMessagesHome(input) {
    this.ensureWorkspace(input.userId);
    const contacts = this.repository.listContacts(input.userId);
    const groups = this.repository.listGroups(input.userId);
    const conversations = this.repository.listRecentConversations(input.userId, input.limit ?? 12);
    const relationships = this.repository.listRelationshipsForOwner(input.userId);
    const contactsById = new Map(contacts.map((contact) => [contact.id, contact]));
    const groupsById = new Map(groups.map((group) => [group.id, group]));
    const relationshipsByContactId = new Map(relationships.map((relationship) => [relationship.contactId, relationship]));
    const memoriesByConversationId = new Map();

    for (const conversation of conversations) {
      memoriesByConversationId.set(
        conversation.id,
        this.repository.listMemorySnapshotsForConversation(conversation.id, 12)
      );
    }

    return {
      route: input.route ?? buildMessagesHomeRoute(),
      recentChats: buildRecentChatCards({
        conversations,
        contactsById,
        groupsById,
        relationshipsByContactId,
        memoriesByConversationId
      }),
      unreadTotal: conversations.reduce((sum, conversation) => sum + conversation.unreadCount, 0)
    };
  }

  openConversation(input) {
    this.ensureWorkspace(input.userId);
    const conversation = this.repository.findConversation(input.conversationId);
    if (!conversation || conversation.ownerUserId !== input.userId) {
      throw new Error(`Unknown conversation: ${input.conversationId}`);
    }

    const markedConversation = input.markRead === false
      ? conversation
      : this.repository.markConversationRead(conversation.id, isoNow());
    const messages = this.repository.listConversationMessages(conversation.id, input.limit ?? 40);
    const participants = this.repository.listConversationParticipants(conversation.id);
    const contact = conversation.contactId ? this.repository.findContact(conversation.contactId) : null;
    const group = conversation.groupId ? this.repository.findGroup(conversation.groupId) : null;
    const relationship = contact
      ? this.repository.findRelationshipByContact(input.userId, contact.id)
      : null;
    const mask = contact ? this.repository.findActiveMask(contact.id) ?? contact.defaultMask : null;
    const rituals = relationship ? this.repository.listRitualsForRelationship(relationship.id) : [];
    const memories = contact
      ? this.repository.listMemorySnapshotsForContact(contact.id, 18)
      : this.repository.listMemorySnapshotsForConversation(conversation.id, 18);

    return {
      ...buildConversationContext({
        conversation: markedConversation,
        contact,
        group,
        relationship,
        mask,
        rituals,
        memories
      }),
      messages,
      participants,
      votes: group ? this.repository.listGroupVotes(group.id, 8) : [],
      groupSummaries: group ? this.repository.listGroupSummaries(group.id, 8) : []
    };
  }

  searchConversation(input) {
    this.ensureWorkspace(input.userId);
    const conversation = this.repository.findConversation(input.conversationId);
    if (!conversation || conversation.ownerUserId !== input.userId) {
      throw new Error(`Unknown conversation: ${input.conversationId}`);
    }

    return {
      conversation,
      query: sanitizeText(input.query),
      hits: this.repository.searchConversationMessages(
        conversation.id,
        input.query,
        input.limit ?? 12
      )
    };
  }

  sendDirectMessage(input) {
    this.ensureWorkspace(input.userId);
    const contact = this.repository.findContact(input.contactId);
    if (!contact || contact.userId !== input.userId) {
      throw new Error(`Unknown contact: ${input.contactId}`);
    }
    const conversation = this.repository.findConversationByContact(input.userId, contact.id);
    const relationship = this.repository.findRelationshipByContact(input.userId, contact.id);
    const activeMask = this.repository.findActiveMask(contact.id) ?? contact.defaultMask;
    const messageText = sanitizeText(input.text);
    const recalledMemories = recallRelevantMemorySnapshots({
      snapshots: this.repository.listMemorySnapshotsForContact(contact.id, 18),
      message: messageText
    });
    const assistantText = composeSelfAgentAssist({
      contact,
      userMessage: messageText,
      mask: activeMask,
      recalledMemories,
      relationship
    });
    const replyText = composeCounterpartReply({
      contact,
      userMessage: messageText,
      recalledMemories,
      relationship
    });
    const nowIso = isoNow();

    let userMessage;
    let assistantMessage;
    let counterpartMessage;
    let updatedConversation;
    let updatedRelationship;

    this.repository.withTransaction(() => {
      userMessage = this.repository.appendMessage({
        conversationId: conversation.id,
        actorKey: buildSelfParticipantKey('human'),
        actorRole: 'self_human',
        channelKind: 'timeline',
        content: messageText,
        metadata: {
          entry: 'direct_message'
        },
        unreadForOwner: false,
        createdAt: nowIso
      });
      assistantMessage = this.repository.appendMessage({
        conversationId: conversation.id,
        actorKey: buildSelfParticipantKey('agent'),
        actorRole: 'self_agent',
        channelKind: 'assistant',
        content: assistantText,
        metadata: {
          maskTone: activeMask.tone,
          maskOpenness: activeMask.openness
        },
        unreadForOwner: false,
        createdAt: nowIso
      });
      counterpartMessage = this.repository.appendMessage({
        conversationId: conversation.id,
        actorKey: buildCounterpartParticipantKey(contact.id, 'human'),
        actorRole: 'counterpart_human',
        channelKind: 'timeline',
        content: replyText,
        metadata: {
          recalledMemoryIds: recalledMemories.map((memory) => memory.id)
        },
        unreadForOwner: true,
        createdAt: nowIso
      });

      const relationshipSnapshot = buildRelationshipSnapshot({
        contact,
        warmthScore: relationship.warmthScore + computeWarmthDelta({
          text: `${messageText} ${replyText}`
        }),
        previousSummary: relationship.latestSummary,
        latestInteraction: `${contact.displayName} 回应了“${clipText(replyText, 44)}”`
      });
      updatedRelationship = this.repository.upsertRelationship({
        ...relationship,
        ...relationshipSnapshot,
        ownerUserId: input.userId,
        contactId: contact.id,
        conversationId: conversation.id,
        memorialCard: relationship.memorialCard,
        updatedAt: nowIso
      });

      this.repository.saveMemorySnapshots(
        buildLayeredMemorySnapshots({
          userId: input.userId,
          contactId: contact.id,
          counterpartName: contact.displayName,
          conversationId: conversation.id,
          userMessage: messageText,
          counterpartMessage: replyText,
          relationship: updatedRelationship,
          sourceMessageIds: [userMessage.id, counterpartMessage.id],
          nowIso
        })
      );

      updatedConversation = this.repository.updateConversationAfterMessage({
        conversationId: conversation.id,
        lastMessagePreview: replyText,
        lastMessageAt: nowIso,
        unreadIncrement: 1,
        nowIso
      });
    });

    return {
      conversation: updatedConversation,
      contact,
      mask: activeMask,
      relationship: updatedRelationship,
      recalledMemories,
      assistantMessage,
      messages: this.repository.listConversationMessages(conversation.id, 16),
      recentChats: this.openMessagesHome({
        userId: input.userId,
        limit: 8
      }).recentChats
    };
  }

  updateContactMask(input) {
    this.ensureWorkspace(input.userId);
    const contact = this.repository.findContact(input.contactId);
    if (!contact || contact.userId !== input.userId) {
      throw new Error(`Unknown contact: ${input.contactId}`);
    }
    const conversation = this.repository.findConversationByContact(input.userId, contact.id);
    const previousMask = this.repository.findActiveMask(contact.id) ?? contact.defaultMask;
    const nowIso = isoNow();
    const nextMask = {
      id: stableId('companion-mask', contact.id, nowIso),
      contactId: contact.id,
      tone: resolveMaskTone(input.tone, previousMask.tone ?? contact.defaultMask.tone),
      openness: resolveMaskOpenness(
        input.openness,
        previousMask.openness ?? contact.defaultMask.openness
      ),
      boundaryTags: uniqueStrings(
        input.boundaryTags?.length
          ? input.boundaryTags
          : previousMask.boundaryTags ?? contact.defaultMask.boundaryTags
      ),
      signature:
        sanitizeText(input.signature) ||
        previousMask.signature ||
        contact.defaultMask.signature,
      overrideRules: uniqueStrings(input.overrideRules ?? previousMask.overrideRules ?? []),
      isActive: true,
      createdAt: nowIso,
      updatedAt: nowIso
    };
    const changeSummary =
      sanitizeText(input.changeSummary) ||
      `把对 ${contact.displayName} 的面具调成 ${nextMask.tone}/${nextMask.openness}`;
    const systemText = `${changeSummary}。当前规则：${nextMask.boundaryTags.slice(0, 3).join('、')}`;

    this.repository.withTransaction(() => {
      this.repository.deactivateMasks(contact.id, nowIso);
      this.repository.insertMask(nextMask);
      this.repository.recordMaskHistory({
        contactId: contact.id,
        maskId: nextMask.id,
        changeSummary,
        diff: {
          from: collectMaskTerms(previousMask),
          to: collectMaskTerms(nextMask),
          overrideRules: nextMask.overrideRules
        },
        createdAt: nowIso
      });
      this.repository.appendMessage({
        conversationId: conversation.id,
        actorKey: buildSelfParticipantKey('agent'),
        actorRole: 'self_agent',
        channelKind: 'assistant',
        content: systemText,
        metadata: {
          changeType: 'mask_override'
        },
        unreadForOwner: false,
        createdAt: nowIso
      });
      this.repository.updateConversationAfterMessage({
        conversationId: conversation.id,
        lastMessagePreview: systemText,
        lastMessageAt: nowIso,
        unreadIncrement: 0,
        nowIso
      });
    });

    return {
      contact,
      mask: this.repository.findActiveMask(contact.id),
      history: this.repository.listMaskHistory(contact.id),
      conversation: this.repository.findConversation(conversation.id)
    };
  }

  draftSharedStage(input) {
    this.ensureWorkspace(input.userId);
    const contact = this.repository.findContact(input.contactId);
    if (!contact || contact.userId !== input.userId) {
      throw new Error(`Unknown contact: ${input.contactId}`);
    }
    const relationship = this.repository.findRelationshipByContact(input.userId, contact.id);
    const activeMask = this.repository.findActiveMask(contact.id) ?? contact.defaultMask;
    const messageText = sanitizeText(input.text);
    const recalledMemories = recallRelevantMemorySnapshots({
      snapshots: this.repository.listMemorySnapshotsForContact(contact.id, 18),
      message: messageText
    });

    return {
      contact,
      relationship,
      recalledMemories,
      selfAgentDraft: composeSelfAgentAssist({
        contact,
        userMessage: messageText,
        mask: activeMask,
        recalledMemories,
        relationship
      }),
      counterpartAgentDraft: composeCounterpartAgentReply({
        contact,
        userMessage: messageText,
        relationship
      })
    };
  }

  grantStageAccess(input) {
    this.ensureWorkspace(input.userId);
    const conversation = this.repository.findConversation(input.conversationId);
    if (!conversation || conversation.ownerUserId !== input.userId) {
      throw new Error(`Unknown conversation: ${input.conversationId}`);
    }
    const participant = this.repository.findParticipant(conversation.id, input.participantKey);
    if (!participant) {
      throw new Error(`Unknown participant: ${input.participantKey}`);
    }
    const updated = this.repository.updateParticipantPermission({
      conversationId: conversation.id,
      participantKey: participant.participantKey,
      permissions: {
        ...participant.permissions,
        canPost: Boolean(input.granted)
      },
      nowIso: isoNow()
    });
    return {
      conversation,
      participant: updated,
      participants: this.repository.listConversationParticipants(conversation.id)
    };
  }

  postStageMessage(input) {
    this.ensureWorkspace(input.userId);
    const conversation = this.repository.findConversation(input.conversationId);
    if (!conversation || conversation.ownerUserId !== input.userId) {
      throw new Error(`Unknown conversation: ${input.conversationId}`);
    }
    const participant = this.repository.findParticipant(conversation.id, input.participantKey);
    if (!participant?.permissions?.canPost) {
      throw new Error(`Participant cannot post in this stage: ${input.participantKey}`);
    }

    const nowIso = isoNow();
    const content = sanitizeText(input.content);
    let relationship = conversation.contactId
      ? this.repository.findRelationshipByContact(input.userId, conversation.contactId)
      : null;
    const contact = conversation.contactId ? this.repository.findContact(conversation.contactId) : null;

    let message;
    this.repository.withTransaction(() => {
      message = this.repository.appendMessage({
        conversationId: conversation.id,
        actorKey: participant.participantKey,
        actorRole: participant.role,
        channelKind: sanitizeText(input.channelKind) || 'timeline',
        content,
        metadata: {
          stageMode: 'shared_stage'
        },
        unreadForOwner: !isOwnerParticipantKey(participant.participantKey),
        createdAt: nowIso
      });
      this.repository.updateConversationAfterMessage({
        conversationId: conversation.id,
        lastMessagePreview: content,
        lastMessageAt: nowIso,
        unreadIncrement: isOwnerParticipantKey(participant.participantKey) ? 0 : 1,
        nowIso
      });

      if (relationship && contact) {
        const updatedRelationship = buildRelationshipSnapshot({
          contact,
          warmthScore: relationship.warmthScore + computeWarmthDelta({ text: content }),
          previousSummary: relationship.latestSummary,
          latestInteraction: `四角色同场新增了一条 ${participant.displayName} 消息`
        });
        relationship = this.repository.upsertRelationship({
          ...relationship,
          ...updatedRelationship,
          updatedAt: nowIso
        });

        if (!isOwnerParticipantKey(participant.participantKey)) {
          const recentMessages = this.repository.listConversationMessages(conversation.id, 8);
          const latestSelfMessage = [...recentMessages].reverse().find((item) => item.actorRole === 'self_human');
          if (latestSelfMessage) {
            this.repository.saveMemorySnapshots(
              buildLayeredMemorySnapshots({
                userId: input.userId,
                contactId: contact.id,
                counterpartName: contact.displayName,
                conversationId: conversation.id,
                userMessage: latestSelfMessage.content,
                counterpartMessage: content,
                relationship,
                sourceMessageIds: [latestSelfMessage.id, message.id],
                nowIso
              })
            );
          }
        }
      }
    });

    return {
      conversation: this.repository.findConversation(conversation.id),
      participant,
      message,
      relationship,
      messages: this.repository.listConversationMessages(conversation.id, 24)
    };
  }

  scheduleRelationshipRitual(input) {
    this.ensureWorkspace(input.userId);
    const contact = this.repository.findContact(input.contactId);
    if (!contact || contact.userId !== input.userId) {
      throw new Error(`Unknown contact: ${input.contactId}`);
    }
    const relationship = this.repository.findRelationshipByContact(input.userId, contact.id);
    const conversation = this.repository.findConversationByContact(input.userId, contact.id);
    const kind = resolveRitualKind(input.kind);
    const nowIso = isoNow();
    const ritual = buildRitualRecord({
      contact,
      relationship,
      kind,
      scheduledFor: input.scheduledFor ?? null,
      note: input.note,
      nowIso
    });

    this.repository.withTransaction(() => {
      this.repository.createRitual({
        ...ritual,
        createdAt: nowIso,
        updatedAt: nowIso
      });
      this.repository.appendMessage({
        conversationId: conversation.id,
        actorKey: buildSelfParticipantKey('agent'),
        actorRole: 'self_agent',
        channelKind: 'assistant',
        content: ritual.summary,
        metadata: {
          ritualId: ritual.ritualId,
          ritualKind: kind
        },
        unreadForOwner: false,
        createdAt: nowIso
      });
      this.repository.updateConversationAfterMessage({
        conversationId: conversation.id,
        lastMessagePreview: ritual.summary,
        lastMessageAt: nowIso,
        unreadIncrement: 0,
        nowIso
      });
    });

    return {
      conversation: this.repository.findConversation(conversation.id),
      ritual: this.repository.findRitual(ritual.ritualId),
      rituals: this.repository.listRitualsForRelationship(relationship.id)
    };
  }

  completeRelationshipRitual(input) {
    this.ensureWorkspace(input.userId);
    const ritual = this.repository.findRitual(input.ritualId);
    if (!ritual) {
      throw new Error(`Unknown ritual: ${input.ritualId}`);
    }
    const relationship = this.repository.findRelationship(ritual.relationshipId);
    if (!relationship || relationship.ownerUserId !== input.userId) {
      throw new Error(`Unknown relationship for ritual: ${input.ritualId}`);
    }
    const contact = this.repository.findContact(relationship.contactId);
    const nowIso = isoNow();
    const completionSummary = `${ritual.summary}${sanitizeText(input.note) ? ` 完成备注：${sanitizeText(input.note)}` : ''}`;
    const completedMemorialCard = {
      ...(ritual.memorialCard ?? {}),
      summary: clipText(completionSummary, 84),
      completedAt: nowIso
    };
    const memoryLaneSummary =
      ritual.memoryLaneSummary ??
      `${contact.displayName} 的回忆线新增了一次“${ritual.title}”完成记录。`;

    let updatedRelationship;
    let assistantMessage;

    this.repository.withTransaction(() => {
      const completed = this.repository.completeRitual({
        ritualId: ritual.id,
        summary: completionSummary,
        memorialCard: completedMemorialCard,
        memoryLaneSummary,
        completedAt: nowIso,
        nowIso
      });

      const relationshipSnapshot = buildRelationshipSnapshot({
        contact,
        warmthScore:
          relationship.warmthScore +
          computeWarmthDelta({
            text: input.note ?? ritual.summary,
            ritualKind: ritual.ritualKind
          }),
        previousSummary: relationship.latestSummary,
        latestInteraction: `${ritual.title} 已完成`
      });
      updatedRelationship = this.repository.upsertRelationship({
        ...relationship,
        ...relationshipSnapshot,
        memorialCard: completed.memorialCard,
        lastRitualAt: nowIso,
        updatedAt: nowIso
      });

      assistantMessage = this.repository.appendMessage({
        conversationId: relationship.conversationId,
        actorKey: buildSelfParticipantKey('agent'),
        actorRole: 'self_agent',
        channelKind: 'summary',
        content: `${ritual.title} 已完成。${memoryLaneSummary}`,
        metadata: {
          ritualId: ritual.id,
          state: 'completed'
        },
        unreadForOwner: false,
        createdAt: nowIso
      });
      this.repository.updateConversationAfterMessage({
        conversationId: relationship.conversationId,
        lastMessagePreview: assistantMessage.content,
        lastMessageAt: nowIso,
        unreadIncrement: 0,
        nowIso
      });

      this.repository.saveMemorySnapshots(
        buildLayeredMemorySnapshots({
          userId: input.userId,
          contactId: contact.id,
          counterpartName: contact.displayName,
          conversationId: relationship.conversationId,
          userMessage: completionSummary,
          counterpartMessage: memoryLaneSummary,
          relationship: updatedRelationship,
          sourceMessageIds: [assistantMessage.id],
          nowIso
        })
      );
    });

    return {
      ritual: this.repository.findRitual(ritual.id),
      relationship: updatedRelationship,
      conversation: this.repository.findConversation(relationship.conversationId),
      rituals: this.repository.listRitualsForRelationship(relationship.id)
    };
  }

  openGroupConversation(input) {
    this.ensureWorkspace(input.userId);
    const group = this.repository.findGroup(input.groupId);
    if (!group || group.ownerUserId !== input.userId) {
      throw new Error(`Unknown group: ${input.groupId}`);
    }
    const conversation = this.repository.markConversationRead(
      this.repository.findConversationByGroup(input.userId, group.id).id,
      isoNow()
    );
    return {
      group,
      conversation,
      participants: this.repository.listConversationParticipants(conversation.id),
      groupMembers: this.repository.listGroupMembers(group.id),
      messages: this.repository.listConversationMessages(conversation.id, input.limit ?? 40),
      votes: this.repository.listGroupVotes(group.id, 8),
      summaries: this.repository.listGroupSummaries(group.id, 8)
    };
  }

  postGroupMessage(input) {
    this.ensureWorkspace(input.userId);
    const group = this.repository.findGroup(input.groupId);
    if (!group || group.ownerUserId !== input.userId) {
      throw new Error(`Unknown group: ${input.groupId}`);
    }
    const conversation = this.repository.findConversationByGroup(input.userId, group.id);
    const participant = this.repository.findParticipant(conversation.id, input.actorKey);
    if (!participant?.permissions?.canPost) {
      throw new Error(`Participant cannot post in group: ${input.actorKey}`);
    }

    const nowIso = isoNow();
    const content = sanitizeText(input.content);
    const signalScore = scoreMessageSignal(content);
    const suppressed = signalScore < group.noiseThreshold;
    const message = this.repository.appendMessage({
      conversationId: conversation.id,
      actorKey: participant.participantKey,
      actorRole: participant.role,
      channelKind: sanitizeText(input.channelKind) || 'timeline',
      content,
      metadata: {
        groupId: group.id
      },
      signalScore,
      suppressed,
      unreadForOwner: !isOwnerParticipantKey(participant.participantKey),
      createdAt: nowIso
    });
    const updatedConversation = this.repository.updateConversationAfterMessage({
      conversationId: conversation.id,
      lastMessagePreview: content,
      lastMessageAt: nowIso,
      unreadIncrement: isOwnerParticipantKey(participant.participantKey) ? 0 : 1,
      nowIso
    });

    return {
      group,
      conversation: updatedConversation,
      message,
      signalScore,
      suppressed
    };
  }

  launchGroupVote(input) {
    this.ensureWorkspace(input.userId);
    const group = this.repository.findGroup(input.groupId);
    if (!group || group.ownerUserId !== input.userId) {
      throw new Error(`Unknown group: ${input.groupId}`);
    }
    const conversation = this.repository.findConversationByGroup(input.userId, group.id);
    const nowIso = isoNow();
    const voteBlueprint = buildGroupVote({
      groupId: group.id,
      question: input.question,
      options: input.options,
      createdBy: buildSelfParticipantKey('human'),
      nowIso
    });
    const vote = {
      ...voteBlueprint,
      conversationId: conversation.id
    };

    let announcement;
    this.repository.withTransaction(() => {
      this.repository.createGroupVote(vote);
      announcement = this.repository.appendMessage({
        conversationId: conversation.id,
        actorKey: buildGroupParticipantKey(group.id, 'tool_agent'),
        actorRole: 'tool_agent',
        channelKind: 'vote',
        content: `发起投票：${sanitizeText(input.question)}`,
        metadata: {
          voteId: vote.id,
          options: vote.options
        },
        unreadForOwner: false,
        createdAt: nowIso
      });
      this.repository.updateConversationAfterMessage({
        conversationId: conversation.id,
        lastMessagePreview: announcement.content,
        lastMessageAt: nowIso,
        unreadIncrement: 0,
        nowIso
      });
    });

    return {
      group,
      vote: this.repository.findGroupVote(vote.id),
      announcement,
      votes: this.repository.listGroupVotes(group.id, 8)
    };
  }

  castGroupVote(input) {
    this.ensureWorkspace(input.userId);
    const vote = this.repository.findGroupVote(input.voteId);
    if (!vote) {
      throw new Error(`Unknown vote: ${input.voteId}`);
    }
    if (vote.status === 'closed') {
      throw new Error(`Vote already closed: ${input.voteId}`);
    }
    const group = this.repository.findGroup(vote.groupId);
    const ballot = this.repository.saveGroupBallot({
      voteId: vote.id,
      voterKey: input.voterKey,
      optionId: input.optionId,
      rationale: input.rationale,
      createdAt: isoNow()
    });
    const ballots = this.repository.listGroupBallots(vote.id);
    const voterCount = this.repository
      .listGroupMembers(group.id)
      .filter((member) => member.role !== 'tool_agent').length;
    let updatedVote = vote;

    if (ballots.length >= voterCount) {
      const tally = tallyGroupVote({
        vote,
        ballots
      });
      updatedVote = this.repository.closeGroupVote({
        voteId: vote.id,
        resultSummary: tally.winningOption
          ? `投票结果：${tally.winningOption.label}（${tally.winningOption.count} 票）`
          : '投票已关闭'
      });
    }

    return {
      group,
      vote: updatedVote,
      ballot,
      ballots
    };
  }

  summarizeGroup(input) {
    this.ensureWorkspace(input.userId);
    const group = this.repository.findGroup(input.groupId);
    if (!group || group.ownerUserId !== input.userId) {
      throw new Error(`Unknown group: ${input.groupId}`);
    }
    const conversation = this.repository.findConversationByGroup(input.userId, group.id);
    const vote =
      (input.voteId && this.repository.findGroupVote(input.voteId)) ||
      this.repository.listGroupVotes(group.id, 1)[0] ||
      null;
    const ballots = vote ? this.repository.listGroupBallots(vote.id) : [];
    const messages = this.repository.listConversationMessages(conversation.id, 40);
    const summaryPayload = buildGroupSummary({
      group,
      messages,
      vote,
      ballots
    });
    const nowIso = isoNow();

    const summaryRecord = this.repository.saveGroupSummary({
      groupId: group.id,
      conversationId: conversation.id,
      summary: summaryPayload.summary,
      includedMessageIds: messages.filter((message) => !message.suppressed).map((message) => message.id),
      suppressedCount: summaryPayload.suppressedCount,
      nowIso
    });
    const summaryMessage = this.repository.appendMessage({
      conversationId: conversation.id,
      actorKey: buildGroupParticipantKey(group.id, 'tool_agent'),
      actorRole: 'tool_agent',
      channelKind: 'summary',
      content: summaryPayload.summary,
      metadata: {
        summaryId: summaryRecord.id,
        winningOption: summaryPayload.winningOption
      },
      unreadForOwner: false,
      createdAt: nowIso
    });
    const updatedConversation = this.repository.updateConversationAfterMessage({
      conversationId: conversation.id,
      lastMessagePreview: summaryPayload.summary,
      lastMessageAt: nowIso,
      unreadIncrement: 0,
      nowIso
    });

    return {
      group,
      conversation: updatedConversation,
      summary: summaryRecord,
      summaryMessage,
      vote,
      ballots
    };
  }

  inspectCompanionState(userId) {
    this.ensureWorkspace(userId);
    const contacts = this.repository.listContacts(userId);
    const groups = this.repository.listGroups(userId);
    const relationships = this.repository.listRelationshipsForOwner(userId);
    const recentConversations = this.repository.listRecentConversations(userId, 8);
    const recentChats = this.openMessagesHome({
      userId,
      limit: 8
    }).recentChats;

    return {
      counts: this.repository.inspectCounts(userId),
      contacts,
      groups: groups.map((group) => ({
        ...group,
        votes: this.repository.listGroupVotes(group.id, 4),
        summaries: this.repository.listGroupSummaries(group.id, 4)
      })),
      relationships: relationships.map((relationship) => ({
        ...relationship,
        rituals: this.repository.listRitualsForRelationship(relationship.id),
        activeMask: this.repository.findActiveMask(relationship.contactId),
        memories: this.repository.listMemorySnapshotsForContact(relationship.contactId, 6)
      })),
      recentConversations: recentConversations.map((conversation) => ({
        ...conversation,
        messages: this.repository.listConversationMessages(conversation.id, 10)
      })),
      recentChats
    };
  }
}
