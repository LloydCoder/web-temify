import { describe, expect, it } from "vitest";
import { getServerEnv } from "./env";

describe("server environment", () => {
  it("defaults external agent integration to disabled", () => {
    expect(getServerEnv().TINLANCE_AGENT_SYSTEM_ENABLED).toBe("false");
  });
  it("defaults payment processing to disabled until a provider is approved", () => {
    expect(getServerEnv().PAYMENT_PROVIDER).toBe("disabled");
  });
});
