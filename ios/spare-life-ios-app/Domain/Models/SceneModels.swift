// SceneModels.swift
// Spare Life – 咸虾 scene domain models
// UIUX lane – slot 2

import Foundation

// MARK: - Scene Category

enum SceneCategory: String, CaseIterable, Identifiable {
    case all      = "全部"
    case restaurant = "餐厅"
    case event    = "活动"
    case brand    = "品牌"
    case office   = "办公楼"
    case expo     = "展会"
    case campus   = "校园"
    case community = "社区"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .all:        return "square.grid.2x2"
        case .restaurant: return "fork.knife"
        case .event:      return "party.popper"
        case .brand:      return "tag"
        case .office:     return "building.2"
        case .expo:       return "flag.checkered"
        case .campus:     return "graduationcap"
        case .community:  return "house"
        }
    }
}

// MARK: - Scan Target (QR code decoded payload)

struct ScanTarget: Identifiable, Equatable {
    let id: String
    let sceneID: String
    let type: ScanTargetType
    let displayName: String
    let sceneCategory: SceneCategory
    let deepLinkURL: URL?

    enum ScanTargetType: String {
        case qrCode     = "qr"
        case shortLink  = "short_link"
        case activityCode = "activity"
        case inviteCode = "invite"
    }
}

// MARK: - Scene Model

struct Scene: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let category: SceneCategory
    let description: String?
    let coverImageURL: URL?
    let participantCount: Int
    let activeAvatarCount: Int
    let lastActivityAt: Date
    var isFeatured: Bool = false
}

// MARK: - Scene Feed Item

enum SceneFeedItem: Identifiable {
    case summary(SceneSummaryCard)
    case hotTake(HotTakeCard)
    case avatarRadar(SceneAvatarCard)
    case socialPrompt(SceneSocialPromptCard)

    var id: String {
        switch self {
        case .summary(let c):      return "summary-\(c.id)"
        case .hotTake(let c):      return "hottake-\(c.id)"
        case .avatarRadar(let c):  return "avatar-\(c.id)"
        case .socialPrompt(let c): return "social-\(c.id)"
        }
    }
}

// MARK: - Scene Summary Card (AI-generated scene overview)

struct SceneSummaryCard: Identifiable, Equatable {
    let id: String
    let sceneID: String
    let oneLiner: String                // The "what's happening" hook sentence
    let emotionLabel: EmotionLabel
    let topicClusters: [TopicCluster]
    let participantCount: Int
    let generatedAt: Date
    let expiresAt: Date

    var isStale: Bool { Date() > expiresAt }
}

// MARK: - Hot Take Card (high-engagement opinion)

struct HotTakeCard: Identifiable, Equatable {
    let id: String
    let sceneID: String
    let content: String
    let authorAvatarName: String        // Display name for avatar placeholder
    let authorIsAnonymous: Bool
    let likeCount: Int
    let replyCount: Int
    let emotionLabel: EmotionLabel
    let tags: [String]
    let postedAt: Date
    var sourcePostIDs: [String] = []    // Traceable back to original posts
}

// MARK: - Scene Avatar Card (active persona in scene)

struct SceneAvatarCard: Identifiable, Equatable {
    let id: String
    let agentID: String
    let displayName: String
    let tagline: String
    let intentTags: [String]
    let talkableTopics: [String]
    let activityScore: Int              // 0–100 presence score in scene
    let reputationScore: Int            // 0–100 trust score
    let allowsStrangerInit: Bool        // Can stranger agent open conversation?
    let privacyRadius: PrivacyRadius
    let joinedSceneAt: Date

    enum PrivacyRadius: String, CaseIterable {
        case full    = "完整展示"
        case limited = "部分展示"
        case minimal = "最小展示"
    }
}

// MARK: - Scene Social Prompt Card

struct SceneSocialPromptCard: Identifiable, Equatable {
    let id: String
    let sceneID: String
    let headline: String
    let ctaLabel: String
    let lane: SocialLane

    enum SocialLane: String, CaseIterable, Identifiable {
        case friend     = "交个朋友"
        case meal       = "一起吃饭"
        case collab     = "聊合作"
        case jobSeek    = "求职咨询"
        case skill      = "技能交流"
        case errand     = "跑腿求助"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .friend:  return "person.2"
            case .meal:    return "fork.knife"
            case .collab:  return "briefcase"
            case .jobSeek: return "person.crop.rectangle"
            case .skill:   return "lightbulb"
            case .errand:  return "figure.walk"
            }
        }
    }
}

// MARK: - Topic Cluster (AI clustered discussion topic)

struct TopicCluster: Identifiable, Equatable {
    let id: String
    let label: String
    let sentiment: EmotionLabel
    let postCount: Int
    let keyPhrases: [String]
}

// MARK: - Emotion Label

enum EmotionLabel: String, CaseIterable, Equatable {
    case positive = "positive"
    case negative = "negative"
    case split    = "split"
    case neutral  = "neutral"

    var displayText: String {
        switch self {
        case .positive: return "正向"
        case .negative: return "负向"
        case .split:    return "分裂"
        case .neutral:  return "中性"
        }
    }

    var asBadgeEmotion: EmotionBadge.Emotion {
        switch self {
        case .positive: return .positive
        case .negative: return .negative
        case .split:    return .split
        case .neutral:  return .neutral
        }
    }
}

// MARK: - Intent Draft (for scene-initiated stranger social)

struct IntentDraft: Identifiable {
    var id: String = UUID().uuidString
    let sceneID: String
    let sceneName: String
    var lane: SceneSocialPromptCard.SocialLane
    var note: String = ""
    var mode: InitMode = .avatarFirst
    var riskLevel: RiskLevel = .low
    let createdAt: Date = Date()

    enum InitMode: String, CaseIterable {
        case humanFirst     = "真人先聊"
        case avatarFirst    = "分身先聊"
        case dualAvatar     = "双方分身先聊"

        var description: String {
            switch self {
            case .humanFirst:  return "直接真人对话，更直接"
            case .avatarFirst: return "让你的分身先探探风，保护隐私"
            case .dualAvatar:  return "双方分身先接触，人工破冰"
            }
        }

        var icon: String {
            switch self {
            case .humanFirst:  return "person.fill"
            case .avatarFirst: return "person.crop.circle.badge.questionmark"
            case .dualAvatar:  return "person.2.fill"
            }
        }
    }

    enum RiskLevel: String {
        case low    = "low"
        case medium = "medium"
        case high   = "high"
    }
}

// MARK: - Avatar Sort Option

enum AvatarSortOption: String, CaseIterable, Identifiable {
    case hottest  = "最热"
    case newest   = "最新"
    case matched  = "最匹配"
    case trusted  = "最可信"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .hottest:  return "flame"
        case .newest:   return "clock"
        case .matched:  return "target"
        case .trusted:  return "checkmark.shield"
        }
    }
}

// MARK: - Scene Feed Load State

enum SceneFeedState {
    case idle
    case loading
    case loaded([SceneFeedItem])
    case loadedFromCache([SceneFeedItem])   // network failed, showing cached data
    case empty
    case error(String)
}

// MARK: - Scene Presence (agent active in scene)

struct SceneAgentPresence: Identifiable, Equatable {
    let id: String
    let agentID: String
    let sceneID: String
    let activityScore: Int
    let tags: [String]
    let reputation: Int
    let joinedAt: Date
}
