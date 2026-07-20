using System.ComponentModel;
using System.Text.Json;
using ModelContextProtocol.Server;

namespace AshitaGuide.Mcp;

[McpServerToolType]
public static class AuctionSaleGuideTools
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = false,
    };

    [McpServerTool]
    [Description("Publishes one temporary, display-only Auction House sale guide to AshitaGuide. Publishing replaces the current sale guide. The player must perform every Auction House action manually.")]
    public static string publish_auction_sale_guide(
        [Description("One to 80 validated sale suggestions. Equipment and currently equipped items must be excluded unless the user explicitly requested equipment cleanup.")]
        IReadOnlyList<AuctionSaleItemInput> items,
        [Description("Guide tab title. Defaults to 'Auction House Sale List'.")]
        string title = "Auction House Sale List",
        [Description("Short context shown above the sale list.")]
        string summary = "Sell these items manually at an Auction House.")
    {
        try
        {
            var result = AuctionSaleGuideStorage.Publish(items, title, summary);
            return JsonSerializer.Serialize(new
            {
                ok = true,
                replacedCurrentGuide = result.ReplacedCurrentGuide,
                itemCount = result.ItemCount,
                title = result.Title,
                lifecycle = "Closing the guide tab deletes this sale list forever.",
                safety = "Display only. No items were moved or listed and no game command was sent.",
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
                error = $"Auction sale guide could not be published: {ex.Message}",
            }, JsonOptions);
        }
    }

    [McpServerTool]
    [Description("Reports whether a temporary Auction House sale guide is currently published for AshitaGuide.")]
    public static string auction_sale_guide_status()
    {
        try
        {
            var status = AuctionSaleGuideStorage.GetStatus();
            return JsonSerializer.Serialize(new
            {
                ok = true,
                status.Published,
                status.LastUpdatedUtc,
                lifecycle = "Closing the guide tab deletes the publication file.",
            }, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }
}
