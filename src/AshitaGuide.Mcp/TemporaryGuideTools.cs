using System.ComponentModel;
using System.Text.Json;
using ModelContextProtocol.Server;

namespace AshitaGuide.Mcp;

[McpServerToolType]
public static class TemporaryGuideTools
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = false,
    };

    [McpServerTool]
    [Description("Publishes or updates one structured, display-only temporary guide in AshitaGuide. Other temporary guides are preserved. The guide appears without an addon reload.")]
    public static string publish_temporary_guide(
        [Description("Structured temporary guide to publish or update by stable key.")] TemporaryGuideInput guide)
    {
        try
        {
            var result = TemporaryGuideStorage.Publish(guide);
            return JsonSerializer.Serialize(new
            {
                ok = true,
                result.Key,
                result.Name,
                result.StepCount,
                result.ReplacedExistingGuide,
                result.TotalGuideCount,
                lifecycle = "Closing this AI guide's tab deletes it from temporary storage. It can be made permanent in Guide Config.",
                safety = "Display only. No game command, input, target change, packet, or gameplay action was sent.",
            }, JsonOptions);
        }
        catch (ArgumentException ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new
            {
                ok = false,
                error = $"Temporary guide could not be published: {ex.Message}",
            }, JsonOptions);
        }
    }

    [McpServerTool]
    [Description("Lists temporary AI guides currently published in AshitaGuide and reports the publication file update time.")]
    public static string temporary_guides_status()
    {
        try
        {
            var status = TemporaryGuideStorage.GetStatus();
            return JsonSerializer.Serialize(new
            {
                ok = true,
                status.Published,
                status.LastUpdatedUtc,
                guideCount = status.Guides.Count,
                guides = status.Guides.Select(guide => new
                {
                    guide.Key,
                    guide.Name,
                    guide.StepCount,
                }),
            }, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }
}
