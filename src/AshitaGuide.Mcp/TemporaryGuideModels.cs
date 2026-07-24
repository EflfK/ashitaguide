using System.ComponentModel;

namespace AshitaGuide.Mcp;

public sealed class TemporaryGuideInput
{
    [Description("Stable unique key using lowercase letters, numbers, underscores, or hyphens.")]
    public required string Key { get; init; }

    [Description("Guide tab title.")]
    public required string Name { get; init; }

    [Description("Optional context shown in the guide picker and AI Guides configuration tab.")]
    public string? Description { get; init; }

    [Description("Optional categories used by AshitaGuide's normal guide filters.")]
    public IReadOnlyList<string>? Categories { get; init; }

    [Description("One to 100 ordered, display-only guide steps.")]
    public required IReadOnlyList<TemporaryGuideStepInput> Steps { get; init; }
}

public sealed class TemporaryGuideStepInput
{
    [Description("Optional short step heading.")]
    public string? Title { get; init; }

    [Description("Instruction shown to the player.")]
    public required string Text { get; init; }

    [Description("Optional destination zone name.")]
    public string? Zone { get; init; }

    [Description("Optional human-readable map location such as H-8.")]
    public string? Location { get; init; }

    [Description("Optional exact NPC name used for the display marker.")]
    public string? Npc { get; init; }

    [Description("Optional dialog answer or response reminder.")]
    public string? Answer { get; init; }

    [Description("Optional caution or supporting note.")]
    public string? Note { get; init; }

    [Description("Optional destination X coordinate. Supply targetY as well.")]
    public double? TargetX { get; init; }

    [Description("Optional destination Y coordinate. Supply targetX as well.")]
    public double? TargetY { get; init; }

    [Description("Optional live Minimap map/floor id from 0 through 255. The Minimap marker is hidden while another map is displayed.")]
    public int? MapId { get; init; }

    [Description("Optional additional destinations rendered together on the guide map and Minimap. Use this for one-step guides that need several simultaneous markers.")]
    public IReadOnlyList<TemporaryGuideDestinationInput>? Destinations { get; init; }

    [Description("Optional key-item resource name that persistently marks this step done when already owned or newly obtained. Use keyItemId when names are duplicated.")]
    public string? KeyItem { get; init; }

    [Description("Optional key-item resource id from 0 through 65535 that persistently marks this step done when already owned or newly obtained.")]
    public int? KeyItemId { get; init; }

    [Description("Optional main-job level, from 1 through 99, that completes this step.")]
    public int? MinimumLevel { get; init; }

    [Description("Optional job abbreviation or full job name restricting minimumLevel completion.")]
    public string? RequiredJob { get; init; }

    [Description("When true, selecting the named NPC advances this display guide. No target or game command is sent.")]
    public bool AdvanceOnTarget { get; init; }

    [Description("Optional exact phrase that advances this step when it appears in a new incoming chat event. Matching ignores case, punctuation, and repeated whitespace; no chat-log polling is added.")]
    public string? AdvanceOnText { get; init; }
}

public sealed class TemporaryGuideDestinationInput
{
    [Description("Optional short marker label.")]
    public string? Label { get; init; }

    [Description("Optional exact NPC name used for live-position resolution. Omit it when marking fixed spawn possibilities.")]
    public string? Npc { get; init; }

    [Description("Destination X coordinate.")]
    public required double TargetX { get; init; }

    [Description("Destination Y coordinate.")]
    public required double TargetY { get; init; }

    [Description("Optional live Minimap map/floor id from 0 through 255. The marker is hidden while another map is displayed.")]
    public int? MapId { get; init; }
}
