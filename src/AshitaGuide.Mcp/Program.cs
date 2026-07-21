using AshitaGuide.Mcp;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModelContextProtocol.Server;

if (args.Contains("--self-test", StringComparer.OrdinalIgnoreCase))
{
    AuctionSaleGuideStorage.RunSelfTest();
    TemporaryGuideStorage.RunSelfTest();
    Console.WriteLine("AshitaGuide MCP self-test passed.");
    return;
}

var builder = Host.CreateApplicationBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddConsole(options =>
{
    options.LogToStandardErrorThreshold = LogLevel.Trace;
});

builder.Services
    .AddMcpServer()
    .WithStdioServerTransport()
    .WithToolsFromAssembly();

await builder.Build().RunAsync();
