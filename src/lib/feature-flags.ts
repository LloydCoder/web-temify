function isEnabled(value: string | undefined): boolean {
  return (
    value !== undefined &&
    ["1", "true", "yes", "on"].includes(value.toLowerCase())
  );
}
/** Server-side capabilities default off until implementation and rollout are reviewed. */
export const featureFlags = Object.freeze({
  cryptoPayments: isEnabled(process.env.NEXT_PUBLIC_FEATURE_CRYPTO_PAYMENTS),
  tinlanceAgentIntegration: isEnabled(
    process.env.TINLANCE_AGENT_INTEGRATION_ENABLED,
  ),
  vendorMarketplace: isEnabled(process.env.FEATURE_VENDOR_MARKETPLACE),
  aiProductGenerator: isEnabled(process.env.FEATURE_AI_PRODUCT_GENERATOR),
});
