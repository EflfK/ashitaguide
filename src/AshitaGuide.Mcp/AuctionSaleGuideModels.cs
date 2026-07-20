using System.ComponentModel;

namespace AshitaGuide.Mcp;

public sealed class AuctionSaleItemInput
{
    [Description("Exact in-game item name.")]
    public required string Name { get; init; }

    [Description("Optional numeric Ashita item resource id.")]
    public int? ItemId { get; init; }

    [Description("Number of this item currently owned and intended for the sale list.")]
    public required int QuantityOwned { get; init; }

    [Description("Quantity in each Auction House listing: 1 for a single or the full stack size for a stack.")]
    public required int ListingQuantity { get; init; }

    [Description("Suggested gil price for one complete Auction House listing, not a per-item price.")]
    public required int SuggestedPriceGil { get; init; }

    [Description("Short market evidence for the suggestion, such as recent stack sales or median completed sales.")]
    public string? PriceBasis { get; init; }

    [Description("Date or timestamp when the market evidence was observed.")]
    public string? ObservedAt { get; init; }

    [Description("Optional warning or sale note shown with the item.")]
    public string? Note { get; init; }
}
