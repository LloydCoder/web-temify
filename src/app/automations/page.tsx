import type { Metadata } from "next";
import EcosystemDestination from "../ecosystem-destination";

export const metadata: Metadata = {
  title: "Verified Automation Marketplace",
  description:
    "Automation verification, installation and transactions are planned.",
  alternates: { canonical: "/automations" },
};

export default function AutomationsPage() {
  return <EcosystemDestination area="automations" />;
}
