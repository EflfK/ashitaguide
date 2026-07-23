using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace AshitaGuide.Mcp;

public static partial class TemporaryGuideStorage
{
    private const string PublicationFileName = "ai_guides.lua";
    private const string DefaultAshitaRoot = @"C:\Games\CatsEyeXI\catseyexi-client\Ashita";
    private const int MaximumGuides = 40;
    private static readonly UTF8Encoding Utf8NoBom = new(false);
    private static readonly object PublicationLock = new();

    public static TemporaryGuidePublishResult Publish(TemporaryGuideInput? input)
    {
        var guide = NormalizeInput(input);
        lock (PublicationLock)
        {
            var path = ResolvePublicationPath();
            var guides = ReadGuides(path).ToList();
            var existingIndex = guides.FindIndex(candidate =>
                string.Equals(candidate.Key, guide.Key, StringComparison.OrdinalIgnoreCase));
            var replaced = existingIndex >= 0;
            if (replaced)
            {
                guides[existingIndex] = guide;
            }
            else
            {
                if (guides.Count >= MaximumGuides)
                {
                    throw new ArgumentException($"Temporary guide storage can contain at most {MaximumGuides} guides.");
                }
                guides.Add(guide);
            }

            WriteGuides(path, guides);
            return new TemporaryGuidePublishResult(
                guide.Key,
                guide.Name,
                guide.Steps.Count,
                replaced,
                guides.Count);
        }
    }

    public static TemporaryGuidesStatus GetStatus()
    {
        lock (PublicationLock)
        {
            var path = ResolvePublicationPath();
            if (!File.Exists(path))
            {
                return new TemporaryGuidesStatus(false, null, Array.Empty<TemporaryGuideSummary>());
            }

            var guides = ReadGuides(path);
            return new TemporaryGuidesStatus(
                guides.Count > 0,
                File.GetLastWriteTimeUtc(path),
                guides.Select(guide => new TemporaryGuideSummary(guide.Key, guide.Name, guide.Steps.Count)).ToArray());
        }
    }

    public static void RunSelfTest()
    {
        var previous = Environment.GetEnvironmentVariable("ASHITAGUIDE_CONFIG_DIR");
        var testDirectory = Path.Combine(Path.GetTempPath(), $"ashitaguide-temporary-mcp-{Guid.NewGuid():N}");
        try
        {
            Environment.SetEnvironmentVariable("ASHITAGUIDE_CONFIG_DIR", testDirectory);
            Directory.CreateDirectory(testDirectory);
            File.WriteAllText(
                Path.Combine(testDirectory, PublicationFileName),
                "return { guides = { { key = \"legacy_sale\", name = \"Legacy Sale\", type = \"auction_sale_list\", description = \"\", categories = {}, steps = { { title = \"Sell\", text = \"Manual sale.\", advance_on_target = false, sale_items = { { name = \"Fire Crystal\", quantity_owned = 12, listing_quantity = 12, suggested_price_gil = 4000, price_basis = \"Test\", observed_at = \"2026-07-21\", note = \"\" }, }, }, }, }, }, };",
                Utf8NoBom);
            var first = Publish(new TemporaryGuideInput
            {
                Key = "ai_current_goal",
                Name = "Current Goal",
                Description = "Temporary \"quoted\" context.",
                Categories = new[] { "Quest", "AI" },
                Steps = new[]
                {
                    new TemporaryGuideStepInput
                    {
                        Title = "Talk to the NPC",
                        Text = "Speak with Mendi.",
                        Zone = "Lower Jeuno",
                        Location = "H-8",
                        Npc = "Mendi",
                        TargetX = -59.961,
                        TargetY = -75.649,
                        MapId = 15,
                        AdvanceOnText = "You have undertaken All for One",
                    },
                },
            });
            var second = Publish(new TemporaryGuideInput
            {
                Key = "ai_level_goal",
                Name = "Level Goal",
                Steps = new[]
                {
                    new TemporaryGuideStepInput
                    {
                        Text = "Reach level 30 as Beastmaster.",
                        MinimumLevel = 30,
                        RequiredJob = "BST",
                    },
                },
            });
            var replacement = Publish(new TemporaryGuideInput
            {
                Key = "ai_current_goal",
                Name = "Updated Goal",
                Steps = new[] { new TemporaryGuideStepInput { Text = "Updated instruction." } },
            });

            var status = GetStatus();
            var contents = File.ReadAllText(Path.Combine(testDirectory, PublicationFileName));
            if (first.ReplacedExistingGuide
                || second.ReplacedExistingGuide
                || !replacement.ReplacedExistingGuide
                || replacement.TotalGuideCount != 3
                || status.Guides.Count != 3
                || !contents.Contains("name = \"Updated Goal\"", StringComparison.Ordinal)
                || !contents.Contains("key = \"ai_level_goal\"", StringComparison.Ordinal)
                || !contents.Contains("name = \"Fire Crystal\"", StringComparison.Ordinal)
                || !contents.Contains("map_id = 15", StringComparison.Ordinal)
                || !contents.Contains("advance_on_text = \"You have undertaken All for One\"", StringComparison.Ordinal)
                || contents.Contains("name = \"Current Goal\"", StringComparison.Ordinal))
            {
                throw new InvalidOperationException("Temporary guide upsert self-test failed.");
            }

            try
            {
                Publish(new TemporaryGuideInput
                {
                    Key = "invalid_coordinates",
                    Name = "Invalid Coordinates",
                    Steps = new[] { new TemporaryGuideStepInput { Text = "Invalid.", TargetX = 1 } },
                });
                throw new InvalidOperationException("Invalid coordinate validation self-test failed.");
            }
            catch (ArgumentException)
            {
            }

            var malicious = "return os.execute(\"should-not-run\")";
            File.WriteAllText(Path.Combine(testDirectory, PublicationFileName), malicious, Utf8NoBom);
            try
            {
                GetStatus();
                throw new InvalidOperationException("Executable Lua rejection self-test failed.");
            }
            catch (InvalidOperationException ex) when (ex.Message.Contains("not safe structured guide data", StringComparison.Ordinal))
            {
            }
            if (File.ReadAllText(Path.Combine(testDirectory, PublicationFileName)) != malicious)
            {
                throw new InvalidOperationException("Unsafe Lua was unexpectedly changed.");
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

    private static StoredGuide NormalizeInput(TemporaryGuideInput? input)
    {
        if (input is null)
        {
            throw new ArgumentException("guide is required.", nameof(input));
        }
        var key = CleanText(input.Key, 64, "guide.key").ToLowerInvariant();
        if (!GuideKeyPattern().IsMatch(key))
        {
            throw new ArgumentException("guide.key must start with a lowercase letter and contain only lowercase letters, numbers, underscores, or hyphens.");
        }
        var name = CleanText(input.Name, 96, "guide.name");
        var description = CleanOptionalText(input.Description, 512, "guide.description");
        var categories = NormalizeCategories(input.Categories);
        if (input.Steps is null || input.Steps.Count == 0 || input.Steps.Count > 100)
        {
            throw new ArgumentException("guide.steps must contain between 1 and 100 steps.");
        }
        var steps = input.Steps.Select((step, index) => NormalizeStep(step, index)).ToArray();
        return new StoredGuide(key, name, "manual", description, categories, steps);
    }

    private static StoredStep NormalizeStep(TemporaryGuideStepInput? input, int index)
    {
        if (input is null)
        {
            throw new ArgumentException($"guide.steps[{index}] is required.");
        }
        if (input.TargetX.HasValue != input.TargetY.HasValue)
        {
            throw new ArgumentException($"guide.steps[{index}].targetX and targetY must be supplied together.");
        }
        if (input.TargetX is double x && (!double.IsFinite(x) || Math.Abs(x) > 100_000))
        {
            throw new ArgumentException($"guide.steps[{index}].targetX must be a finite coordinate between -100000 and 100000.");
        }
        if (input.TargetY is double y && (!double.IsFinite(y) || Math.Abs(y) > 100_000))
        {
            throw new ArgumentException($"guide.steps[{index}].targetY must be a finite coordinate between -100000 and 100000.");
        }
        if (input.MapId is < 0 or > 255)
        {
            throw new ArgumentException($"guide.steps[{index}].mapId must be between 0 and 255.");
        }
        if (input.MinimumLevel is < 1 or > 99)
        {
            throw new ArgumentException($"guide.steps[{index}].minimumLevel must be between 1 and 99.");
        }
        var requiredJob = CleanOptionalText(input.RequiredJob, 32, $"guide.steps[{index}].requiredJob");
        if (requiredJob.Length > 0 && !JobPattern().IsMatch(requiredJob))
        {
            throw new ArgumentException($"guide.steps[{index}].requiredJob must contain only letters and spaces.");
        }

        return new StoredStep(
            CleanOptionalText(input.Title, 128, $"guide.steps[{index}].title"),
            CleanText(input.Text, 2048, $"guide.steps[{index}].text"),
            CleanOptionalText(input.Zone, 96, $"guide.steps[{index}].zone"),
            CleanOptionalText(input.Location, 64, $"guide.steps[{index}].location"),
            CleanOptionalText(input.Npc, 96, $"guide.steps[{index}].npc"),
            CleanOptionalText(input.Answer, 512, $"guide.steps[{index}].answer"),
            CleanOptionalText(input.Note, 512, $"guide.steps[{index}].note"),
            input.TargetX,
            input.TargetY,
            input.MapId,
            input.MinimumLevel,
            requiredJob,
            input.AdvanceOnTarget,
            CleanOptionalText(input.AdvanceOnText, 256, $"guide.steps[{index}].advanceOnText"),
            Array.Empty<StoredSaleItem>());
    }

    private static IReadOnlyList<string> NormalizeCategories(IReadOnlyList<string>? categories)
    {
        if (categories is null)
        {
            return Array.Empty<string>();
        }
        if (categories.Count > 12)
        {
            throw new ArgumentException("guide.categories can contain at most 12 entries.");
        }
        return categories
            .Select((category, index) => CleanText(category, 48, $"guide.categories[{index}]"))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static IReadOnlyList<StoredGuide> ReadGuides(string path)
    {
        if (!File.Exists(path))
        {
            return Array.Empty<StoredGuide>();
        }
        var contents = File.ReadAllText(path);
        if (string.IsNullOrWhiteSpace(contents))
        {
            return Array.Empty<StoredGuide>();
        }

        try
        {
            var root = new LuaDataParser(contents).ParseDocument();
            var guidesTable = root.GetTable("guides")
                ?? throw new FormatException("The root table must contain a guides table.");
            var guides = guidesTable.ArrayValues.Select(item => ParseStoredGuide(item.RequireTable())).ToArray();
            if (guides.Length > MaximumGuides)
            {
                throw new FormatException($"The file contains more than {MaximumGuides} guides.");
            }
            var duplicate = guides.GroupBy(guide => guide.Key, StringComparer.OrdinalIgnoreCase).FirstOrDefault(group => group.Count() > 1);
            if (duplicate is not null)
            {
                throw new FormatException($"The file contains duplicate guide key '{duplicate.Key}'.");
            }
            return guides;
        }
        catch (Exception ex) when (ex is FormatException or InvalidOperationException)
        {
            throw new InvalidOperationException($"{PublicationFileName} is not safe structured guide data and was not changed: {ex.Message}", ex);
        }
    }

    private static StoredGuide ParseStoredGuide(LuaTableValue value)
    {
        var key = value.RequireString("key");
        var name = value.RequireString("name");
        var type = value.GetString("type") ?? "manual";
        var description = value.GetString("description") ?? string.Empty;
        var categories = value.GetTable("categories")?.ArrayValues.Select(item => item.RequireScalarString()).ToArray()
            ?? Array.Empty<string>();
        var stepsTable = value.GetTable("steps") ?? throw new FormatException($"Guide '{key}' must contain a steps table.");
        var steps = stepsTable.ArrayValues.Select(item => ParseStoredStep(item.RequireTable())).ToArray();
        if (steps.Length == 0)
        {
            throw new FormatException($"Guide '{key}' must contain at least one step.");
        }
        return new StoredGuide(key, name, type, description, categories, steps);
    }

    private static StoredStep ParseStoredStep(LuaTableValue value)
    {
        var saleItems = value.GetTable("sale_items")?.ArrayValues.Select(item => ParseStoredSaleItem(item.RequireTable())).ToArray()
            ?? Array.Empty<StoredSaleItem>();
        return new StoredStep(
            value.GetString("title") ?? string.Empty,
            value.RequireString("text"),
            value.GetString("zone") ?? string.Empty,
            value.GetString("location") ?? string.Empty,
            value.GetString("npc") ?? string.Empty,
            value.GetString("answer") ?? string.Empty,
            value.GetString("note") ?? string.Empty,
            value.GetDouble("target_x"),
            value.GetDouble("target_y"),
            value.GetInt("map_id"),
            value.GetInt("minimum_level"),
            value.GetString("required_job") ?? string.Empty,
            value.GetBool("advance_on_target") ?? false,
            value.GetString("advance_on_text") ?? string.Empty,
            saleItems);
    }

    private static StoredSaleItem ParseStoredSaleItem(LuaTableValue value) => new(
        value.RequireString("name"),
        value.GetInt("item_id"),
        value.GetInt("quantity_owned") ?? throw new FormatException("Sale item quantity_owned must be an integer."),
        value.GetInt("listing_quantity") ?? throw new FormatException("Sale item listing_quantity must be an integer."),
        value.GetInt("suggested_price_gil") ?? throw new FormatException("Sale item suggested_price_gil must be an integer."),
        value.GetString("price_basis") ?? string.Empty,
        value.GetString("observed_at") ?? string.Empty,
        value.GetString("note") ?? string.Empty);

    private static void WriteGuides(string path, IReadOnlyList<StoredGuide> guides)
    {
        var directory = Path.GetDirectoryName(path) ?? throw new InvalidOperationException("Temporary guide path has no parent directory.");
        Directory.CreateDirectory(directory);
        var tempPath = Path.Combine(directory, $".{PublicationFileName}.{Guid.NewGuid():N}.tmp");
        try
        {
            File.WriteAllText(tempPath, RenderLua(guides), Utf8NoBom);
            File.Move(tempPath, path, true);
        }
        finally
        {
            if (File.Exists(tempPath))
            {
                File.Delete(tempPath);
            }
        }
    }

    private static string RenderLua(IReadOnlyList<StoredGuide> guides)
    {
        var output = new StringBuilder();
        output.AppendLine("-- Generated by AshitaGuide.Mcp. Structured display data only.");
        output.AppendLine("return {");
        output.AppendLine("    guides = {");
        foreach (var guide in guides)
        {
            output.AppendLine("        {");
            output.AppendLine($"            key = {LuaQuote(guide.Key)},");
            output.AppendLine($"            name = {LuaQuote(guide.Name)},");
            output.AppendLine($"            type = {LuaQuote(guide.Type)},");
            output.AppendLine($"            description = {LuaQuote(guide.Description)},");
            output.AppendLine("            categories = {");
            foreach (var category in guide.Categories)
            {
                output.AppendLine($"                {LuaQuote(category)},");
            }
            output.AppendLine("            },");
            output.AppendLine("            steps = {");
            foreach (var step in guide.Steps)
            {
                output.AppendLine("                {");
                output.AppendLine($"                    title = {LuaQuote(step.Title)},");
                output.AppendLine($"                    text = {LuaQuote(step.Text)},");
                output.AppendLine($"                    zone = {LuaQuote(step.Zone)},");
                output.AppendLine($"                    location = {LuaQuote(step.Location)},");
                output.AppendLine($"                    npc = {LuaQuote(step.Npc)},");
                output.AppendLine($"                    answer = {LuaQuote(step.Answer)},");
                output.AppendLine($"                    note = {LuaQuote(step.Note)},");
                if (step.TargetX is not null)
                {
                    output.AppendLine($"                    target_x = {step.TargetX.Value.ToString("R", CultureInfo.InvariantCulture)},");
                    output.AppendLine($"                    target_y = {step.TargetY!.Value.ToString("R", CultureInfo.InvariantCulture)},");
                }
                if (step.MapId is not null)
                {
                    output.AppendLine($"                    map_id = {step.MapId.Value.ToString(CultureInfo.InvariantCulture)},");
                }
                if (step.MinimumLevel is not null)
                {
                    output.AppendLine($"                    minimum_level = {step.MinimumLevel.Value.ToString(CultureInfo.InvariantCulture)},");
                }
                if (step.RequiredJob.Length > 0)
                {
                    output.AppendLine($"                    required_job = {LuaQuote(step.RequiredJob)},");
                }
                output.AppendLine($"                    advance_on_target = {(step.AdvanceOnTarget ? "true" : "false")},");
                if (step.AdvanceOnText.Length > 0)
                {
                    output.AppendLine($"                    advance_on_text = {LuaQuote(step.AdvanceOnText)},");
                }
                if (step.SaleItems.Count > 0)
                {
                    output.AppendLine("                    sale_items = {");
                    foreach (var item in step.SaleItems)
                    {
                        output.AppendLine("                        {");
                        output.AppendLine($"                            name = {LuaQuote(item.Name)},");
                        if (item.ItemId is not null)
                        {
                            output.AppendLine($"                            item_id = {item.ItemId.Value.ToString(CultureInfo.InvariantCulture)},");
                        }
                        output.AppendLine($"                            quantity_owned = {item.QuantityOwned.ToString(CultureInfo.InvariantCulture)},");
                        output.AppendLine($"                            listing_quantity = {item.ListingQuantity.ToString(CultureInfo.InvariantCulture)},");
                        output.AppendLine($"                            suggested_price_gil = {item.SuggestedPriceGil.ToString(CultureInfo.InvariantCulture)},");
                        output.AppendLine($"                            price_basis = {LuaQuote(item.PriceBasis)},");
                        output.AppendLine($"                            observed_at = {LuaQuote(item.ObservedAt)},");
                        output.AppendLine($"                            note = {LuaQuote(item.Note)},");
                        output.AppendLine("                        },");
                    }
                    output.AppendLine("                    },");
                }
                output.AppendLine("                },");
            }
            output.AppendLine("            },");
            output.AppendLine("        },");
        }
        output.AppendLine("    },");
        output.AppendLine("};");
        return output.ToString();
    }

    private static string ResolvePublicationPath()
    {
        var configured = Environment.GetEnvironmentVariable("ASHITAGUIDE_CONFIG_DIR");
        if (!string.IsNullOrWhiteSpace(configured))
        {
            return Path.Combine(Path.GetFullPath(configured.Trim()), PublicationFileName);
        }
        var ashitaRoot = Environment.GetEnvironmentVariable("ASHITA_ROOT");
        var root = string.IsNullOrWhiteSpace(ashitaRoot) ? DefaultAshitaRoot : ashitaRoot.Trim();
        return Path.Combine(Path.GetFullPath(root), "config", "addons", "ashitaguide", PublicationFileName);
    }

    private static string LuaQuote(string value)
    {
        var output = new StringBuilder(value.Length + 2).Append('"');
        foreach (var character in value)
        {
            output.Append(character switch
            {
                '\\' => "\\\\",
                '"' => "\\\"",
                '\n' => "\\n",
                '\r' => "\\r",
                '\t' => "\\t",
                _ => character.ToString(),
            });
        }
        return output.Append('"').ToString();
    }

    private static string CleanText(string? value, int maximumLength, string field)
    {
        var clean = CollapseWhitespace(value);
        if (clean.Length == 0)
        {
            throw new ArgumentException($"{field} is required.");
        }
        if (clean.Length > maximumLength)
        {
            throw new ArgumentException($"{field} cannot exceed {maximumLength} characters.");
        }
        return clean;
    }

    private static string CleanOptionalText(string? value, int maximumLength, string field)
    {
        var clean = CollapseWhitespace(value);
        if (clean.Length > maximumLength)
        {
            throw new ArgumentException($"{field} cannot exceed {maximumLength} characters.");
        }
        return clean;
    }

    private static string CollapseWhitespace(string? value) =>
        string.Join(' ', (value ?? string.Empty).Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));

    [GeneratedRegex("^[a-z][a-z0-9_-]{0,63}$", RegexOptions.CultureInvariant)]
    private static partial Regex GuideKeyPattern();

    [GeneratedRegex("^[A-Za-z ]+$", RegexOptions.CultureInvariant)]
    private static partial Regex JobPattern();

    private sealed record StoredGuide(
        string Key,
        string Name,
        string Type,
        string Description,
        IReadOnlyList<string> Categories,
        IReadOnlyList<StoredStep> Steps);

    private sealed record StoredStep(
        string Title,
        string Text,
        string Zone,
        string Location,
        string Npc,
        string Answer,
        string Note,
        double? TargetX,
        double? TargetY,
        int? MapId,
        int? MinimumLevel,
        string RequiredJob,
        bool AdvanceOnTarget,
        string AdvanceOnText,
        IReadOnlyList<StoredSaleItem> SaleItems);

    private sealed record StoredSaleItem(
        string Name,
        int? ItemId,
        int QuantityOwned,
        int ListingQuantity,
        int SuggestedPriceGil,
        string PriceBasis,
        string ObservedAt,
        string Note);
}

public sealed record TemporaryGuidePublishResult(
    string Key,
    string Name,
    int StepCount,
    bool ReplacedExistingGuide,
    int TotalGuideCount);

public sealed record TemporaryGuideSummary(string Key, string Name, int StepCount);

public sealed record TemporaryGuidesStatus(
    bool Published,
    DateTime? LastUpdatedUtc,
    IReadOnlyList<TemporaryGuideSummary> Guides);

internal sealed class LuaTableValue
{
    public Dictionary<string, object?> Fields { get; } = new(StringComparer.Ordinal);
    public List<object?> ArrayValues { get; } = new();

    public LuaTableValue? GetTable(string key) => Fields.TryGetValue(key, out var value) ? value as LuaTableValue : null;
    public string? GetString(string key) => Fields.TryGetValue(key, out var value) ? value as string : null;
    public string RequireString(string key) => GetString(key) ?? throw new FormatException($"Field '{key}' must be a string.");
    public double? GetDouble(string key) => Fields.TryGetValue(key, out var value) && value is double number ? number : null;
    public int? GetInt(string key) => GetDouble(key) is double number && number == Math.Truncate(number) ? checked((int)number) : null;
    public bool? GetBool(string key) => Fields.TryGetValue(key, out var value) && value is bool boolean ? boolean : null;
}

internal static class LuaDataValueExtensions
{
    public static LuaTableValue RequireTable(this object? value) =>
        value as LuaTableValue ?? throw new FormatException("Expected a table value.");

    public static string RequireScalarString(this object? value) =>
        value as string ?? throw new FormatException("Expected a string array value.");
}

internal sealed class LuaDataParser(string text)
{
    private int position;

    public LuaTableValue ParseDocument()
    {
        SkipTrivia();
        ReadKeyword("return");
        var root = ParseValue().RequireTable();
        SkipTrivia();
        TryConsume(';');
        SkipTrivia();
        if (position != text.Length)
        {
            throw Error("Unexpected content after the returned table.");
        }
        return root;
    }

    private object? ParseValue()
    {
        SkipTrivia();
        if (Peek() == '{') return ParseTable();
        if (Peek() is '\'' or '"') return ParseString();
        if (Peek() == '-' || char.IsDigit(Peek())) return ParseNumber();
        var identifier = ParseIdentifier();
        return identifier switch
        {
            "true" => true,
            "false" => false,
            "nil" => null,
            _ => throw Error($"Unsupported value '{identifier}'. Only structured Lua data is accepted."),
        };
    }

    private LuaTableValue ParseTable()
    {
        Expect('{');
        var table = new LuaTableValue();
        while (true)
        {
            SkipTrivia();
            if (TryConsume('}')) return table;

            var saved = position;
            string? key = null;
            if (IsIdentifierStart(Peek()))
            {
                key = ParseIdentifier();
                SkipTrivia();
                if (!TryConsume('='))
                {
                    position = saved;
                    key = null;
                }
            }

            var value = ParseValue();
            if (key is null)
            {
                table.ArrayValues.Add(value);
            }
            else if (!table.Fields.TryAdd(key, value))
            {
                throw Error($"Duplicate field '{key}'.");
            }

            SkipTrivia();
            if (!TryConsume(',') && !TryConsume(';') && Peek() != '}')
            {
                throw Error("Expected ',', ';', or '}' after table value.");
            }
        }
    }

    private string ParseString()
    {
        var quote = Read();
        var output = new StringBuilder();
        while (position < text.Length)
        {
            var character = Read();
            if (character == quote) return output.ToString();
            if (character != '\\')
            {
                output.Append(character);
                continue;
            }
            if (position >= text.Length) throw Error("Unterminated string escape.");
            var escaped = Read();
            output.Append(escaped switch
            {
                'a' => '\a',
                'b' => '\b',
                'f' => '\f',
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                'v' => '\v',
                '\\' => '\\',
                '\'' => '\'',
                '"' => '"',
                _ => throw Error($"Unsupported string escape '\\{escaped}'."),
            });
        }
        throw Error("Unterminated string.");
    }

    private double ParseNumber()
    {
        var start = position;
        if (Peek() == '-') position++;
        while (char.IsDigit(Peek())) position++;
        if (Peek() == '.')
        {
            position++;
            while (char.IsDigit(Peek())) position++;
        }
        if (Peek() is 'e' or 'E')
        {
            position++;
            if (Peek() is '+' or '-') position++;
            while (char.IsDigit(Peek())) position++;
        }
        var token = text[start..position];
        if (!double.TryParse(token, NumberStyles.Float, CultureInfo.InvariantCulture, out var value) || !double.IsFinite(value))
        {
            throw Error($"Invalid number '{token}'.");
        }
        return value;
    }

    private string ParseIdentifier()
    {
        if (!IsIdentifierStart(Peek())) throw Error("Expected a structured Lua value.");
        var start = position++;
        while (IsIdentifierPart(Peek())) position++;
        return text[start..position];
    }

    private void ReadKeyword(string keyword)
    {
        var actual = ParseIdentifier();
        if (!string.Equals(actual, keyword, StringComparison.Ordinal)) throw Error($"Expected '{keyword}'.");
    }

    private void SkipTrivia()
    {
        while (true)
        {
            while (char.IsWhiteSpace(Peek())) position++;
            if (Peek() != '-' || Peek(1) != '-') return;
            position += 2;
            while (position < text.Length && Peek() != '\n') position++;
        }
    }

    private bool TryConsume(char expected)
    {
        if (Peek() != expected) return false;
        position++;
        return true;
    }

    private void Expect(char expected)
    {
        SkipTrivia();
        if (!TryConsume(expected)) throw Error($"Expected '{expected}'.");
    }

    private char Read() => position < text.Length ? text[position++] : '\0';
    private char Peek(int offset = 0) => position + offset < text.Length ? text[position + offset] : '\0';
    private static bool IsIdentifierStart(char value) => value == '_' || char.IsLetter(value);
    private static bool IsIdentifierPart(char value) => value == '_' || char.IsLetterOrDigit(value);
    private FormatException Error(string message) => new($"{message} (position {position})");
}
