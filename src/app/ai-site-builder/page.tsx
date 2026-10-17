import type { Metadata } from "next";
import EcosystemDestination from "../ecosystem-destination";

export const metadata: Metadata = {
  title: "AI Site Builder",
  description:
    "AI website generation is planned and disabled until implemented.",
};

export default function AiSiteBuilderPage() {
  return <EcosystemDestination area="ai-site-builder" />;
}
