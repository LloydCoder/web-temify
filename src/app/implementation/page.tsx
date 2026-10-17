import type { Metadata } from "next";
import EcosystemDestination from "../ecosystem-destination";

export const metadata: Metadata = {
  title: "Outcome-Based AI Implementation",
  description: "Scoped AI implementation marketplace workflows are planned; contracts and milestone payments are disabled.",
};

export default function ImplementationPage() {
  return <EcosystemDestination area="implementation" />;
}
