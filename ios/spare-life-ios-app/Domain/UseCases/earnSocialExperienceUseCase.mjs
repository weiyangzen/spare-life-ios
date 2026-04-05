import {
  buildArenaRoute,
  buildIntentDetailRoute,
  buildMessagesThreadRoute,
  buildPersonaDeckRoute,
  buildTrendRoute,
  inferIntentTitle,
  normalizeFormPayload,
  requireIntentTemplate,
  requireLane,
  requireLeadStage,
  requireMatchOutcome,
  resolveLeadSettlementType,
  resolveIcebreakMode,
  resolveVisibilityMode
} from '../Models/a2aContracts.mjs';
import { isoNow, sanitizeText, stableId, uniqueStrings } from '../Models/sceneContracts.mjs';
import {
  assertLeadStageTransition,
  advanceBondProgress,
  bootstrapCatalogSeed,
  buildArenaBlueprint,
  buildArenaEntryRule,
  buildArenaSettlementRule,
  buildBondBlueprint,
  buildLeadPipelineBlueprint,
  buildLeadResultCard,
  buildLeadSettlementRule,
  buildBondTaskRewardRule,
  buildDailyOpenRule,
  buildHomeSnapshot,
  buildIcebreakRewardRule,
  buildIntentCard,
  buildIntentMarketSnapshot,
  buildLaneHeatSnapshot,
  buildRecommendedPersonaDeck,
  buildTrendRewardRule,
  rankLaneTrends,
  runDualAgentIcebreak,
  scoreIntentCandidate,
  scoreArenaMatch
} from '../../Services/EarnSocial/a2aMarketService.mjs';

function toIntentSummary(formPayload) {
  return uniqueStrings(
    Object.entries(formPayload)
      .filter(([, value]) => value !== null && value !== undefined && `${value}` !== '')
      .map(([key, value]) => `${key}:${value}`)
  ).join(' / ');
}

export class EarnSocialExperienceUseCase {
  constructor({ repository }) {
    this.repository = repository;
    this.bootstrapped = false;
  }

  bootstrap() {
    if (this.bootstrapped) {
      return;
    }
    const seed = bootstrapCatalogSeed();
    this.repository.seedLaneCatalog(
      {
        lanes: seed.lanes.map((lane) => ({
          ...lane,
          entryRoute: `sparelife://earn-social/home?lane=${encodeURIComponent(lane.id)}`
        })),
        templatesByLane: seed.templatesByLane
      },
      isoNow()
    );
    this.repository.seedPublicAgentCards(seed.publicCards, isoNow());
    this.repository.seedLaneEvents(seed.laneEvents, isoNow());
    this.repository.seedIntentCandidates(seed.marketIntents, isoNow());
    this.bootstrapped = true;
  }

  recalculateLaneHeat() {
    const lanes = this.repository.listLanes();
    const events = this.repository.listLaneEvents();
    const snapshots = lanes.map((lane) => {
      const openIntents = this.repository.listIntentPosts({
        laneId: lane.id,
        statuses: ['open', 'icebreaking', 'bonded'],
        limit: 200
      }).length;
      const activeIcebreaks = this.repository.listIcebreakSessions({
        laneId: lane.id,
        statuses: ['screening', 'consent_pending', 'human_takeover'],
        limit: 200
      }).length;
      const activePersonas = this.repository.listPublicAgentCards(lane.id).length;
      const activeArenaMatches = this.repository.listArenaMatches({
        laneId: lane.id,
        statuses: ['active', 'resolved'],
        limit: 200
      }).length;
      const eventHeat = events.find((event) => event.laneId === lane.id)?.heatDelta ?? 0;
      return buildLaneHeatSnapshot({
        lane,
        openIntents,
        activeIcebreaks,
        activePersonas,
        activeArenaMatches,
        eventHeat
      });
    });
    this.repository.saveLaneHeatSnapshots(snapshots, isoNow());
    return {
      snapshots,
      ranked: rankLaneTrends(snapshots, events),
      events
    };
  }

  openEarnSocialHome(input) {
    this.bootstrap();
    this.repository.ensureWallet(input.userId, isoNow());
    const dailyRule = buildDailyOpenRule(input.userId);
    const dailyReward = this.repository.awardEnergy({
      userId: input.userId,
      laneId: null,
      amount: dailyRule.amount,
      ruleKey: dailyRule.ruleKey,
      referenceKind: 'home_open',
      referenceId: input.userId,
      dedupeKey: dailyRule.dedupeKey,
      detail: dailyRule.detail,
      nowIso: isoNow()
    });

    const { snapshots, ranked, events } = this.recalculateLaneHeat();
    const laneId = sanitizeText(input.laneId) || null;
    const selectedLaneId = laneId ?? ranked[0]?.laneId ?? 'job_hiring';
    const feedback = this.repository.listPersonaFeedback(input.userId, selectedLaneId);
    const opportunityCards = this.repository
      .listIntentPosts({
        laneId,
        statuses: ['open', 'icebreaking', 'bonded'],
        limit: 12
      })
      .map(buildIntentCard);
    const personaCards = buildRecommendedPersonaDeck({
      laneId: selectedLaneId,
      cards: this.repository.listPublicAgentCards(selectedLaneId),
      viewerTags: input.viewerTags ?? [],
      feedback,
      limit: 6
    });
    const icebreakCards = this.repository.listIcebreakSessions({
      userId: input.userId,
      laneId,
      statuses: ['screening', 'consent_pending', 'human_takeover'],
      limit: 6
    }).map((session) => ({
      sessionId: session.id,
      laneId: session.laneId,
      compatibilityScore: session.compatibilityScore,
      route: session.route,
      summary: session.summary
    }));
    const leadCards = this.repository.listLeadPipelines({
      userId: input.userId,
      laneId,
      limit: 6
    }).map(buildLeadResultCard);
    const arenaCards = this.repository.listArenaMatches({
      laneId,
      statuses: ['active', 'resolved'],
      limit: 6
    }).map((match) => ({
      matchId: match.id,
      laneId: match.laneId,
      arenaScore:
        Number(match.scoreboard?.finalScore?.challenger ?? 0) +
        Number(match.scoreboard?.finalScore?.opponent ?? 0),
      route: match.route,
      summary: match.recap?.summary ?? match.recap?.recap ?? 'A2A 对战进行中'
    }));
    const trendCards = ranked.slice(0, 6);
    const bondCards = this.repository.listActiveBondTasks({
      userId: input.userId,
      laneId,
      limit: 6
    });

    return {
      eventType: 'earn_social_home_ready',
      selectedLaneId,
      dailyReward,
      trends: ranked,
      home: buildHomeSnapshot({
        selectedLaneId: laneId,
        laneStats: snapshots,
        opportunityCards,
        personaCards,
        icebreakCards,
        leadCards,
        arenaCards,
        trendCards,
        bondCards,
        wallet: this.repository.getWallet(input.userId)
      }),
      laneEvents: events
    };
  }

  publishIntent(input) {
    this.bootstrap();
    const lane = requireLane(input.laneId);
    const template = requireIntentTemplate(input.templateId, lane.id);
    const nowIso = isoNow();
    const mode = resolveVisibilityMode(input.mode, 'public');
    const normalizedForm = normalizeFormPayload(template, input.formPayload ?? {});
    const targetCard = sanitizeText(input.targetAgentId) ? this.repository.findPublicAgentCard(input.targetAgentId) : null;
    const intentId = stableId('a2a-intent', input.userId, lane.id, template.id, JSON.stringify(normalizedForm), nowIso);
    const createdIntent = this.repository.createIntentPost(
      {
        id: intentId,
        userId: input.userId,
        laneId: lane.id,
        templateId: template.id,
        title: inferIntentTitle({
          template,
          formPayload: normalizedForm
        }),
        summary: toIntentSummary(normalizedForm),
        mode,
        status: 'open',
        targetAgentId: targetCard?.agentId ?? null,
        formPayload: normalizedForm,
        tags: uniqueStrings([
          ...template.tags,
          ...Object.values(normalizedForm)
            .filter(Boolean)
            .map((value) => sanitizeText(value))
        ]),
        rankingScore: scoreIntentCandidate({
          lane,
          template,
          formPayload: normalizedForm,
          mode,
          targetCard
        }),
        route: buildIntentDetailRoute(intentId)
      },
      nowIso
    );
    this.repository.recordIntentEvent(intentId, 'published', { laneId: lane.id, mode }, nowIso);

    let energyCharge = null;
    if (mode === 'direct') {
      energyCharge = this.repository.spendEnergy({
        userId: input.userId,
        laneId: lane.id,
        amount: 3,
        ruleKey: 'direct_outreach_cost',
        referenceKind: 'intent_post',
        referenceId: intentId,
        dedupeKey: stableId('direct-outreach', intentId),
        detail: {
          templateId: template.id
        },
        nowIso
      });
      if (!energyCharge.applied) {
        throw new Error('Not enough idle energy to publish a direct cold-start intent.');
      }
    }

    const feedback = this.repository.listPersonaFeedback(input.userId, lane.id);
    const recommendedCards = buildRecommendedPersonaDeck({
      laneId: lane.id,
      cards: this.repository.listPublicAgentCards(lane.id),
      intentTags: createdIntent.tags,
      viewerTags: input.viewerTags ?? [],
      feedback,
      limit: 6
    });

    return {
      eventType: 'intent_market_ready',
      intent: createdIntent,
      energyCharge,
      market: buildIntentMarketSnapshot({
        laneId: lane.id,
        templates: this.repository.listTemplatesForLane(lane.id),
        recentIntents: this.repository.listIntentPosts({
          laneId: lane.id,
          statuses: ['open', 'icebreaking', 'bonded'],
          limit: 8
        }).map(buildIntentCard),
        recommendedCards,
        history: this.repository.listIntentHistoryForUser(input.userId, lane.id, 12).map(buildIntentCard)
      })
    };
  }

  browsePersonaDeck(input) {
    this.bootstrap();
    const lane = requireLane(input.laneId);
    const feedback = this.repository.listPersonaFeedback(input.userId, lane.id);
    const hiddenAgentIds = new Set(feedback.filter((item) => ['block', 'report'].includes(item.feedback)).map((item) => item.agentId));
    const shownAgentIds = new Set(feedback.filter((item) => item.feedback === 'shown').map((item) => item.agentId));
    const intent = sanitizeText(input.intentId) ? this.repository.findIntentPost(input.intentId) : null;
    const allCards = this.repository.listPublicAgentCards(lane.id).filter((card) => !hiddenAgentIds.has(card.agentId));
    const recommended = buildRecommendedPersonaDeck({
      laneId: lane.id,
      cards: allCards,
      intentTags: intent?.tags ?? [],
      viewerTags: input.viewerTags ?? [],
      feedback,
      limit: input.limit ?? 6
    });
    const unseen = recommended.filter((card) => !shownAgentIds.has(card.agentId));
    const deck = (unseen.length ? unseen : recommended).slice(0, input.limit ?? 6);
    for (const card of deck) {
      this.repository.recordPersonaFeedback({
        userId: input.userId,
        agentId: card.agentId,
        laneId: lane.id,
        feedback: 'shown',
        detail: {
          intentId: intent?.id ?? null
        },
        nowIso: isoNow()
      });
    }

    return {
      eventType: 'persona_deck_ready',
      laneId: lane.id,
      route: buildPersonaDeckRoute(lane.id),
      cache: {
        seenCount: shownAgentIds.size,
        hiddenCount: hiddenAgentIds.size
      },
      cards: deck
    };
  }

  recordPersonaFeedback(input) {
    this.bootstrap();
    const lane = requireLane(input.laneId);
    const card = this.repository.findPublicAgentCard(input.agentId);
    if (!card) {
      throw new Error(`Unknown public persona card: ${input.agentId}`);
    }
    const feedback = this.repository.recordPersonaFeedback({
      userId: input.userId,
      agentId: input.agentId,
      laneId: lane.id,
      feedback: input.feedback,
      detail: {
        reason: sanitizeText(input.reason)
      },
      nowIso: isoNow()
    });

    let reward = null;
    if (input.feedback === 'like') {
      reward = this.repository.awardEnergy({
        userId: input.userId,
        laneId: lane.id,
        amount: 2,
        ruleKey: 'persona_like_signal',
        referenceKind: 'persona_feedback',
        referenceId: `${input.userId}:${input.agentId}`,
        dedupeKey: stableId('persona-like', input.userId, input.agentId),
        detail: {
          agentId: input.agentId
        },
        nowIso: isoNow()
      });
    }

    return {
      eventType: 'persona_feedback_recorded',
      feedback,
      reward,
      wallet: this.repository.getWallet(input.userId),
      route: buildPersonaDeckRoute(lane.id, input.agentId)
    };
  }

  startDualAgentIcebreak(input) {
    this.bootstrap();
    const intent = this.repository.findIntentPost(input.intentId);
    if (!intent) {
      throw new Error(`Unknown intent post: ${input.intentId}`);
    }
    const targetCard = this.repository.findPublicAgentCard(input.targetAgentId);
    if (!targetCard) {
      throw new Error(`Unknown target persona card: ${input.targetAgentId}`);
    }
    const lane = requireLane(intent.laneId);
    const blueprint = runDualAgentIcebreak({
      lane,
      intent,
      counterpartCard: targetCard,
      nowIso: isoNow()
    });
    const session = this.repository.createIcebreakSession(
      {
        session: {
          sessionId: blueprint.sessionId,
          laneId: lane.id,
          intentId: intent.id,
          initiatorUserId: input.userId,
          targetAgentId: targetCard.agentId,
          counterpartUserId: targetCard.userId,
          mode: resolveIcebreakMode(input.mode, blueprint.mode),
          status: blueprint.status,
          compatibilityScore: blueprint.compatibilityScore,
          handoffRule: blueprint.handoffRule,
          consent: blueprint.consent,
          summary: blueprint.summary,
          route: blueprint.route,
          humanThreadRoute: null
        },
        messages: blueprint.messages
      },
      isoNow()
    );

    this.repository.updateIntentStatus(intent.id, 'icebreaking', { sessionId: session.id }, isoNow());
    this.repository.recordIntentEvent(intent.id, 'icebreak_started', { sessionId: session.id, agentId: targetCard.agentId }, isoNow());

    return {
      eventType: 'dual_agent_icebreak_ready',
      session,
      messages: this.repository.listIcebreakMessages(session.id),
      audits: this.repository.listIcebreakAuditLogs(session.id),
      route: session.route
    };
  }

  recordHumanConsent(input) {
    this.bootstrap();
    const session = this.repository.findIcebreakSession(input.sessionId);
    if (!session) {
      throw new Error(`Unknown icebreak session: ${input.sessionId}`);
    }
    const consent = {
      ...(session.consent ?? {}),
      [input.side]: Boolean(input.granted)
    };
    if (input.granted === false) {
      const updated = this.repository.updateIcebreakSession({
        sessionId: session.id,
        status: 'blocked',
        consent,
        summary: '有一方拒绝真人接手，流程保留在 agent-only 阶段。',
        nowIso: isoNow()
      });
      this.repository.updateIntentStatus(session.intentId, 'open', { blockedSessionId: session.id }, isoNow());
      return {
        eventType: 'dual_agent_consent_recorded',
        session: updated,
        bond: null,
        reward: null
      };
    }

    if (!(consent.initiator && consent.counterpart && session.handoffRule?.auditPassed)) {
      const pending = this.repository.updateIcebreakSession({
        sessionId: session.id,
        status: 'consent_pending',
        consent,
        summary: '已记录单侧授权，等待双方都允许真人接手。',
        nowIso: isoNow()
      });
      return {
        eventType: 'dual_agent_consent_recorded',
        session: pending,
        bond: null,
        reward: null
      };
    }

    const counterpartCard = this.repository.findPublicAgentCard(session.targetAgentId);
    let bond = this.repository.findBondBySession(session.id);
    if (!bond) {
      const bondBlueprint = buildBondBlueprint({
        laneId: session.laneId,
        counterpartCard,
        icebreakSessionId: session.id
      });
      bond = this.repository.createBondRelationship(
        {
          bond: {
            bondId: bondBlueprint.bondId,
            laneId: session.laneId,
            sourceSessionId: session.id,
            initiatorUserId: session.initiatorUserId,
            counterpartUserId: session.counterpartUserId,
            counterpartAgentId: session.targetAgentId,
            level: bondBlueprint.level,
            strengthScore: bondBlueprint.strengthScore,
            status: 'active',
            memorialCard: bondBlueprint.memorialCard,
            threadRoute: bondBlueprint.threadRoute
          },
          tasks: bondBlueprint.tasks
        },
        isoNow()
      );
      this.repository.createThreadMigration({
        bondId: bond.id,
        sessionId: session.id,
        messagesRoute: bond.threadRoute,
        nowIso: isoNow()
      });
    }

    const rewardRule = buildIcebreakRewardRule(session.id, session.laneId);
    const reward = this.repository.awardEnergy({
      userId: session.initiatorUserId,
      laneId: session.laneId,
      amount: rewardRule.amount,
      ruleKey: rewardRule.ruleKey,
      referenceKind: 'icebreak_session',
      referenceId: session.id,
      dedupeKey: rewardRule.dedupeKey,
      detail: rewardRule.detail,
      nowIso: isoNow()
    });
    const updated = this.repository.updateIcebreakSession({
      sessionId: session.id,
      status: 'human_takeover',
      consent,
      summary: '双方已授权真人接手，并生成从陌生到熟人的羁绊任务。',
      humanThreadRoute: buildMessagesThreadRoute({
        bondId: bond.id,
        sessionId: session.id
      }),
      nowIso: isoNow()
    });
    this.repository.updateIntentStatus(session.intentId, 'bonded', { bondId: bond.id, sessionId: session.id }, isoNow());

    const intent = this.repository.findIntentPost(session.intentId);
    let lead = this.repository.findLeadBySession(session.id);
    if (!lead) {
      const leadBlueprint = buildLeadPipelineBlueprint({
        intent,
        session: updated,
        bond,
        counterpartCard
      });
      lead = this.repository.createLeadPipeline(
        {
          lead: leadBlueprint,
          stages: leadBlueprint.stages,
          auditEvents: leadBlueprint.auditEvents
        },
        isoNow()
      );
    }

    return {
      eventType: 'dual_agent_handoff_ready',
      session: updated,
      bond,
      bondTasks: this.repository.listBondTasks(bond.id),
      lead,
      leadStages: this.repository.listLeadStages(lead.id),
      leadAuditTrail: this.repository.listLeadAuditEvents(lead.id),
      reward,
      route: updated.humanThreadRoute
    };
  }

  exploreLaneTrends(input) {
    this.bootstrap();
    const { snapshots, ranked, events } = this.recalculateLaneHeat();
    let reward = null;
    if (sanitizeText(input.claimLaneId)) {
      const event = events.find((item) => item.laneId === input.claimLaneId);
      if (event) {
        const rewardRule = buildTrendRewardRule(event, input.userId);
        reward = this.repository.awardEnergy({
          userId: input.userId,
          laneId: event.laneId,
          amount: rewardRule.amount,
          ruleKey: rewardRule.ruleKey,
          referenceKind: 'lane_event',
          referenceId: event.eventId,
          dedupeKey: rewardRule.dedupeKey,
          detail: rewardRule.detail,
          nowIso: isoNow()
        });
        if (reward.applied) {
          this.repository.recordLaneExplorationReward({
            userId: input.userId,
            laneId: event.laneId,
            eventId: event.eventId,
            ledgerEntryId: reward.entry.id,
            nowIso: isoNow()
          });
        }
      }
    }
    return {
      eventType: 'lane_trends_ready',
      route: buildTrendRoute(input.claimLaneId ?? null),
      snapshots,
      trends: ranked,
      reward
    };
  }

  createArenaMatch(input) {
    this.bootstrap();
    const lane = requireLane(input.laneId);
    const challengerCard = this.repository.findPublicAgentCard(input.challengerAgentId);
    const opponentCard = this.repository.findPublicAgentCard(input.opponentAgentId);
    if (!challengerCard || !opponentCard) {
      throw new Error('Arena match requires both challenger and opponent public cards.');
    }
    const nowIso = isoNow();
    const matchId = stableId('a2a-arena-match', input.userId, lane.id, input.theme, challengerCard.agentId, opponentCard.agentId, nowIso);
    const entryRule = buildArenaEntryRule(matchId, lane.id);
    const frozen = this.repository.freezeEnergy({
      userId: input.userId,
      laneId: lane.id,
      amount: entryRule.amount,
      ruleKey: entryRule.ruleKey,
      referenceKind: 'arena_match',
      referenceId: matchId,
      dedupeKey: entryRule.dedupeKey,
      detail: entryRule.detail,
      nowIso
    });
    if (!frozen.applied) {
      throw new Error('Not enough idle energy to join the A2A arena.');
    }
    const rounds = buildArenaBlueprint({
      laneId: lane.id,
      theme: input.theme,
      challengerCard,
      opponentCard
    });
    const match = this.repository.createArenaMatch(
      {
        match: {
          matchId,
          laneId: lane.id,
          theme: input.theme,
          challengerAgentId: challengerCard.agentId,
          opponentAgentId: opponentCard.agentId,
          createdByUserId: input.userId,
          status: 'active',
          route: buildArenaRoute(matchId)
        },
        rounds
      },
      nowIso
    );

    return {
      eventType: 'arena_match_ready',
      match,
      rounds: this.repository.listArenaRounds(match.id),
      wallet: this.repository.getWallet(input.userId),
      entryFreeze: frozen
    };
  }

  castArenaVote(input) {
    this.bootstrap();
    const vote = this.repository.recordArenaVote({
      matchId: input.matchId,
      voterUserId: input.voterUserId,
      preferredSide: input.preferredSide,
      weight: input.weight ?? 1,
      nowIso: isoNow()
    });
    return {
      eventType: 'arena_vote_recorded',
      vote,
      votes: this.repository.listArenaVotes(input.matchId)
    };
  }

  resolveArenaMatch(input) {
    this.bootstrap();
    const match = this.repository.findArenaMatch(input.matchId);
    if (!match) {
      throw new Error(`Unknown arena match: ${input.matchId}`);
    }
    const rounds = this.repository.listArenaRounds(match.id);
    const votes = this.repository.listArenaVotes(match.id);
    const scored = scoreArenaMatch({ rounds, votes });
    const resolved = this.repository.resolveArenaMatch({
      matchId: match.id,
      winnerSide: scored.winnerSide,
      scoreboard: {
        audience: scored.audience,
        finalScore: scored.finalScore
      },
      recap: {
        summary: scored.recap
      },
      rounds: scored.roundScores,
      nowIso: isoNow()
    });
    const settlementRule = buildArenaSettlementRule(match.id, match.laneId, scored.winnerSide);
    const settlement = this.repository.settleFrozenEnergy({
      userId: input.userId,
      laneId: match.laneId,
      amount: settlementRule.amount,
      releaseFrozenAmount: 5,
      ruleKey: settlementRule.ruleKey,
      referenceKind: 'arena_match',
      referenceId: match.id,
      dedupeKey: settlementRule.dedupeKey,
      detail: settlementRule.detail,
      nowIso: isoNow()
    });

    return {
      eventType: 'arena_match_resolved',
      match: resolved,
      rounds: this.repository.listArenaRounds(match.id),
      votes,
      settlement,
      route: resolved.route
    };
  }

  completeBondTask(input) {
    this.bootstrap();
    const task = this.repository.updateBondTaskProgress({
      taskId: input.taskId,
      increment: input.increment ?? 1,
      nowIso: isoNow()
    });
    const bond = this.repository.findBond(task.bondId);
    const tasks = this.repository.listBondTasks(task.bondId);
    const nextState = advanceBondProgress({
      bond,
      tasks
    });

    let milestone = null;
    if (task.status === 'completed') {
      milestone = this.repository.saveBondMilestone({
        bondId: bond.id,
        milestoneKey: task.milestoneKey,
        title: `羁绊里程碑 · ${task.title}`,
        summary: task.summary,
        achievedAt: isoNow()
      });
      const rewardRule = buildBondTaskRewardRule(task.id, bond.laneId);
      this.repository.awardEnergy({
        userId: input.userId,
        laneId: bond.laneId,
        amount: task.rewardAmount,
        ruleKey: rewardRule.ruleKey,
        referenceKind: 'bond_task',
        referenceId: task.id,
        dedupeKey: rewardRule.dedupeKey,
        detail: {
          bondId: bond.id,
          milestoneKey: task.milestoneKey
        },
        nowIso: isoNow()
      });
    }

    const updatedBond = this.repository.updateBondRelationship({
      bondId: bond.id,
      level: nextState.level,
      strengthScore: nextState.strengthScore,
      milestoneCount: this.repository.listBondMilestones(bond.id).length,
      lastActivityAt: isoNow(),
      status: 'active',
      nowIso: isoNow()
    });

    return {
      eventType: 'bond_progress_updated',
      bond: updatedBond,
      tasks: this.repository.listBondTasks(bond.id),
      milestone,
      wallet: this.repository.getWallet(input.userId),
      route: updatedBond.threadRoute
    };
  }

  advanceLeadStage(input) {
    this.bootstrap();
    const lead = this.repository.findLeadPipeline(input.leadId);
    if (!lead) {
      throw new Error(`Unknown lead pipeline: ${input.leadId}`);
    }
    const nextStage = requireLeadStage(input.stageKey);
    assertLeadStageTransition({
      currentStageKey: lead.currentStageKey,
      nextStageKey: nextStage.key
    });
    const advanced = this.repository.advanceLeadStage({
      leadId: lead.id,
      stageKey: nextStage.key,
      stageLabel: nextStage.label,
      actorKind: 'initiator_user',
      actorId: input.userId,
      detail: input.detail ?? {},
      nowIso: isoNow()
    });
    return {
      eventType: 'lead_stage_advanced',
      lead: advanced.lead,
      stage: advanced.stage,
      audit: advanced.audit,
      stages: this.repository.listLeadStages(lead.id),
      outcome: this.repository.findLeadOutcome(lead.id),
      settlements: this.repository.listLeadSettlements(lead.id),
      route: advanced.lead.route
    };
  }

  recordLeadOutcome(input) {
    this.bootstrap();
    const lead = this.repository.findLeadPipeline(input.leadId);
    if (!lead) {
      throw new Error(`Unknown lead pipeline: ${input.leadId}`);
    }
    if (!['active_delivery', 'result_recorded'].includes(lead.currentStageKey)) {
      throw new Error('Lead outcome can only be recorded after the pipeline enters active_delivery.');
    }
    const outcome = requireMatchOutcome(lead.laneId, input.outcomeCode);
    const nowIso = isoNow();
    const recorded = this.repository.saveLeadOutcome({
      leadId: lead.id,
      laneId: lead.laneId,
      outcomeCode: outcome.code,
      outcomeLabel: outcome.label,
      outcomeStatus: outcome.status,
      recordedByUserId: input.userId,
      detail: input.detail ?? {},
      nowIso
    });

    let stage = null;
    let stageAudit = null;
    if (lead.currentStageKey !== 'result_recorded') {
      const transitioned = this.repository.advanceLeadStage({
        leadId: lead.id,
        stageKey: 'result_recorded',
        stageLabel: requireLeadStage('result_recorded').label,
        actorKind: 'initiator_user',
        actorId: input.userId,
        detail: {
          outcomeCode: outcome.code,
          outcomeLabel: outcome.label,
          ...input.detail
        },
        nowIso
      });
      stage = transitioned.stage;
      stageAudit = transitioned.audit;
    }

    const intentStatus = outcome.status === 'failed' ? 'cancelled' : 'closed';
    const intent = this.repository.updateIntentStatus(
      lead.intentId,
      intentStatus,
      {
        leadId: lead.id,
        outcomeCode: outcome.code,
        outcomeStatus: outcome.status
      },
      nowIso
    );

    return {
      eventType: 'lead_outcome_recorded',
      lead: this.repository.findLeadPipeline(lead.id),
      outcome: recorded.outcome,
      audit: recorded.audit,
      stage,
      stageAudit,
      intent,
      stages: this.repository.listLeadStages(lead.id),
      auditTrail: this.repository.listLeadAuditEvents(lead.id),
      settlements: this.repository.listLeadSettlements(lead.id),
      route: lead.route
    };
  }

  settleLeadOutcome(input) {
    this.bootstrap();
    const lead = this.repository.findLeadPipeline(input.leadId);
    if (!lead) {
      throw new Error(`Unknown lead pipeline: ${input.leadId}`);
    }
    if (!['result_recorded', 'settled'].includes(lead.currentStageKey)) {
      throw new Error('Lead settlement requires a recorded result first.');
    }
    if (![lead.initiatorUserId, lead.counterpartUserId].includes(input.userId)) {
      throw new Error('Lead settlement can only be posted to a pipeline participant.');
    }
    const outcome = this.repository.findLeadOutcome(lead.id);
    if (!outcome) {
      throw new Error(`Lead pipeline ${lead.id} has no recorded outcome yet.`);
    }
    const amount = Number(input.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new Error('Lead settlement amount must be a positive number.');
    }
    const settlementType = resolveLeadSettlementType(input.settlementType, 'reward');
    const nowIso = isoNow();
    const settlementRule = buildLeadSettlementRule({
      leadId: lead.id,
      laneId: lead.laneId,
      beneficiaryUserId: input.userId,
      settlementType
    });
    const settlementLedger = this.repository.awardEnergy({
      userId: input.userId,
      laneId: lead.laneId,
      amount,
      ruleKey: settlementRule.ruleKey,
      referenceKind: 'lead_pipeline',
      referenceId: lead.id,
      dedupeKey: settlementRule.dedupeKey,
      detail: {
        ...settlementRule.detail,
        outcomeCode: outcome.outcomeCode,
        outcomeStatus: outcome.outcomeStatus,
        ...input.detail
      },
      nowIso
    });
    const settlement = this.repository.saveLeadSettlement({
      leadId: lead.id,
      beneficiaryUserId: input.userId,
      settlementType,
      amount,
      status: settlementLedger.applied ? 'posted' : settlementLedger.reason === 'duplicate_rule' ? 'posted' : 'blocked',
      dedupeKey: settlementRule.dedupeKey,
      ledgerEntryId: settlementLedger.entry?.id ?? null,
      detail: {
        ...settlementRule.detail,
        outcomeCode: outcome.outcomeCode,
        outcomeStatus: outcome.outcomeStatus,
        rewardApplied: settlementLedger.applied,
        ...input.detail
      },
      nowIso,
      settledAt: nowIso
    });

    let stage = null;
    let stageAudit = null;
    if (lead.currentStageKey !== 'settled') {
      const transitioned = this.repository.advanceLeadStage({
        leadId: lead.id,
        stageKey: 'settled',
        stageLabel: requireLeadStage('settled').label,
        actorKind: 'system',
        actorId: input.userId,
        detail: {
          settlementType,
          amount,
          ledgerEntryId: settlementLedger.entry?.id ?? null
        },
        nowIso
      });
      stage = transitioned.stage;
      stageAudit = transitioned.audit;
    }

    return {
      eventType: 'lead_settlement_recorded',
      lead: this.repository.findLeadPipeline(lead.id),
      outcome,
      settlement,
      settlementLedger,
      stage,
      stageAudit,
      stages: this.repository.listLeadStages(lead.id),
      auditTrail: this.repository.listLeadAuditEvents(lead.id),
      wallet: this.repository.getWallet(input.userId),
      route: lead.route
    };
  }

  inspectEarnSocialState(userId) {
    this.bootstrap();
    return this.repository.inspectEarnSocialState(userId);
  }
}
