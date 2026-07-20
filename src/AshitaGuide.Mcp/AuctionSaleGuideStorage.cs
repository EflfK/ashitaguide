using System.Globalization;
using System.Text;

namespace AshitaGuide.Mcp;

public static class AuctionSaleGuideStorage
{
    private const string PublicationFileName = "auction_sale_guide.lua";
    private const string DefaultAshitaRoot = @"C:\Games\CatsEyeXI\catseyexi-client\Ashita";
    private static readonly UTF8Encoding Utf8NoBom = new(false);

    public static PublishResult Publish(
        IReadOnlyList<AuctionSaleItemInput>? items,
        string? title,
        string? summary)
    {
        if (items is null || items.Count == 0)
        {
            throw new ArgumentException("At least one sale item is required.", nameof(items));
        }
        if (items.Count > 80)
        {
            throw new ArgumentException("A sale guide can contain at most 80 items.", nameof(items));
        }

        var cleanTitle = CleanText(title, "Auction House Sale List", 96, "title");
        var cleanSummary = CleanText(summary, "Sell these items manually at an Auction House.", 512, "summary");
        var normalized = items.Select((item, index) => NormalizeItem(item, index)).ToArray();
        var configDirectory = ResolveConfigDirectory();
        Directory.CreateDirectory(configDirectory);

        var targetPath = Path.Combine(configDirectory, PublicationFileName);
        var replaced = File.Exists(targetPath);
        var tempPath = Path.Combine(configDirectory, $".{PublicationFileName}.{Guid.NewGuid():N}.tmp");
        try
        {
            File.WriteAllText(tempPath, RenderLua(cleanTitle, cleanSummary, normalized), Utf8NoBom);
            File.Move(tempPath, targetPath, true);
        }
        finally
        {
            if (File.Exists(tempPath))
            {
                File.Delete(tempPath);
            }
        }

        return new PublishResult(replaced, normalized.Length, cleanTitle);
    }

    public static PublicationStatus GetStatus()
    {
        var path = Path.Combine(ResolveConfigDirectory(), PublicationFileName);
        if (!File.Exists(path))
        {
            return new PublicationStatus(false, null);
        }
        return new PublicationStatus(true, File.GetLastWriteTimeUtc(path));
    }

    public static void RunSelfTest()
    {
        var previous = Environment.GetEnvironmentVariable("ASHITAGUIDE_CONFIG_DIR");
        var testDirectory = Path.Combine(Path.GetTempPath(), $"ashitaguide-mcp-{Guid.NewGuid():N}");
        try
        {
            Environment.SetEnvironmentVariable("ASHITAGUIDE_CONFIG_DIR", testDirectory);
            var result = Publish(
                new[]
                {
                    new AuctionSaleItemInput
                    {
                        Name = "Fire Crystal",
                        ItemId = 4096,
                        QuantityOwned = 24,
                        ListingQuantity = 12,
                        SuggestedPriceGil = 4000,
                        PriceBasis = "Recent stack sales",
                        ObservedAt = "2026-07-20",
                    },
                    new AuctionSaleItemInput
                    {
                        Name = "Beetle Jaw \"Test\"",
                        QuantityOwned = 2,
                        ListingQuantity = 1,
                        SuggestedPriceGil = 1000,
                        Note = "List manually.",
                    },
                },
                "Auction House Sale List",
                "Self-test publication.");

            var path = Path.Combine(testDirectory, PublicationFileName);
            var contents = File.ReadAllText(path);
            if (result.ItemCount != 2
                || !contents.Contains("key = \"ai_auction_sale_current\"", StringComparison.Ordinal)
                || !contents.Contains("sale_items = {", StringComparison.Ordinal)
                || !contents.Contains("Beetle Jaw \\\"Test\\\"", StringComparison.Ordinal)
                || contents.Split("steps = {", StringSplitOptions.None).Length != 2)
            {
                throw new InvalidOperationException("Generated publication did not match the fixed one-step contract.");
            }
        }
        finally
        {
            Environment.SetEnvironmentVariable("ASHITAGUIDE_CONFIG_DIR", previous);
            if (Directory.Exists(testDirectory))
            {
                Directory.Delete(testDirectory, true);
            }
        }
    }

    private static NormalizedSaleItem NormalizeItem(AuctionSaleItemInput? item, int index)
    {
        if (item is null)
        {
            throw new ArgumentException($"Sale item {index + 1} is null.", nameof(item));
        }
        var name = CleanText(item.Name, null, 96, $"items[{index}].name");
        if (item.ItemId is < 1 or > 65535)
        {
            throw new ArgumentException($"items[{index}].itemId must be between 1 and 65535 when supplied.");
        }
        if (item.QuantityOwned is < 1 or > 9999)
        {
            throw new ArgumentException($"items[{index}].quantityOwned must be between 1 and 9999.");
        }
        if (item.ListingQuantity is < 1 or > 9999)
        {
            throw new ArgumentException($"items[{index}].listingQuantity must be between 1 and 9999.");
        }
        if (item.ListingQuantity > item.QuantityOwned)
        {
            throw new ArgumentException($"items[{index}].listingQuantity cannot exceed quantityOwned.");
        }
        if (item.SuggestedPriceGil is < 1 or > 999_999_999)
        {
            throw new ArgumentException($"items[{index}].suggestedPriceGil must be between 1 and 999999999.");
        }

        return new NormalizedSaleItem(
            name,
            item.ItemId,
            item.QuantityOwned,
            item.ListingQuantity,
            item.SuggestedPriceGil,
            CleanOptionalText(item.PriceBasis, 256, $"items[{index}].priceBasis"),
            CleanOptionalText(item.ObservedAt, 64, $"items[{index}].observedAt"),
            CleanOptionalText(item.Note, 256, $"items[{index}].note"));
    }

    private static string ResolveConfigDirectory()
    {
        var configured = Environment.GetEnvironmentVariable("ASHITAGUIDE_CONFIG_DIR");
        if (!string.IsNullOrWhiteSpace(configured))
        {
            return Path.GetFullPath(configured.Trim());
        }

        var ashitaRoot = Environment.GetEnvironmentVariable("ASHITA_ROOT");
        var root = string.IsNullOrWhiteSpace(ashitaRoot) ? DefaultAshitaRoot : ashitaRoot.Trim();
        return Path.Combine(Path.GetFullPath(root), "config", "addons", "ashitaguide");
    }

    private static string RenderLua(string title, string summary, IReadOnlyList<NormalizedSaleItem> items)
    {
        var output = new StringBuilder();
        output.AppendLine("-- Generated by AshitaGuide.Mcp. Display data only; do not edit while the publisher is running.");
        output.AppendLine("return {");
        output.AppendLine("    schema = 1,");
        output.AppendLine("    guide = {");
        output.AppendLine("        key = \"ai_auction_sale_current\",");
        output.AppendLine($"        name = {LuaQuote(title)},");
        output.AppendLine("        type = \"auction_sale_list\",");
        output.AppendLine("        description = \"Temporary AI-authored Auction House sale suggestions.\",");
        output.AppendLine("        categories = { \"Auction House\", \"AI\", \"Selling\" },");
        output.AppendLine("        steps = {");
        output.AppendLine("            {");
        output.AppendLine("                title = \"Items to Sell\",");
        output.AppendLine($"                text = {LuaQuote(summary)},");
        output.AppendLine("                sale_items = {");
        foreach (var item in items)
        {
            output.AppendLine("                    {");
            output.AppendLine($"                        name = {LuaQuote(item.Name)},");
            if (item.ItemId is not null)
            {
                output.AppendLine($"                        item_id = {item.ItemId.Value.ToString(CultureInfo.InvariantCulture)},");
            }
            output.AppendLine($"                        quantity_owned = {item.QuantityOwned.ToString(CultureInfo.InvariantCulture)},");
            output.AppendLine($"                        listing_quantity = {item.ListingQuantity.ToString(CultureInfo.InvariantCulture)},");
            output.AppendLine($"                        suggested_price_gil = {item.SuggestedPriceGil.ToString(CultureInfo.InvariantCulture)},");
            output.AppendLine($"                        price_basis = {LuaQuote(item.PriceBasis)},");
            output.AppendLine($"                        observed_at = {LuaQuote(item.ObservedAt)},");
            output.AppendLine($"                        note = {LuaQuote(item.Note)},");
            output.AppendLine("                    },");
        }
        output.AppendLine("                },");
        output.AppendLine("            },");
        output.AppendLine("        },");
        output.AppendLine("    },");
        output.AppendLine("};");
        return output.ToString();
    }

    private static string LuaQuote(string? value) =>
        $"\"{(value ?? string.Empty).Replace("\\", "\\\\", StringComparison.Ordinal).Replace("\"", "\\\"", StringComparison.Ordinal)}\"";

    private static string CleanText(string? value, string? fallback, int maxLength, string field)
    {
        var clean = CollapseWhitespace(value);
        if (clean.Length == 0 && fallback is not null)
        {
            clean = fallback;
        }
        if (clean.Length == 0)
        {
            throw new ArgumentException($"{field} is required.");
        }
        if (clean.Length > maxLength)
        {
            throw new ArgumentException($"{field} cannot exceed {maxLength} characters.");
        }
        return clean;
    }

    private static string CleanOptionalText(string? value, int maxLength, string field)
    {
        var clean = CollapseWhitespace(value);
        if (clean.Length > maxLength)
        {
            throw new ArgumentException($"{field} cannot exceed {maxLength} characters.");
        }
        return clean;
    }

    private static string CollapseWhitespace(string? value) =>
        string.Join(' ', (value ?? string.Empty).Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));

    private sealed record NormalizedSaleItem(
        string Name,
        int? ItemId,
        int QuantityOwned,
        int ListingQuantity,
        int SuggestedPriceGil,
        string PriceBasis,
        string ObservedAt,
        string Note);
}

public sealed record PublishResult(bool ReplacedCurrentGuide, int ItemCount, string Title);

public sealed record PublicationStatus(bool Published, DateTime? LastUpdatedUtc);
