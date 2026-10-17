import type { Metadata } from "next";
import EcosystemDestination from "../ecosystem-destination";

export const metadata: Metadata = {
  title: "Specialist Supplier Directory",
  description:
    "Supplier onboarding and marketplace enquiries are planned, not live.",
  alternates: { canonical: "/specialists" },
};

export default function SpecialistsPage() {
  return <EcosystemDestination area="specialists" />;
}
