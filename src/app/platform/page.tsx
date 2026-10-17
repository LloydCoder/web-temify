import type { Metadata } from "next";
import EcosystemDestination from "../ecosystem-destination";

export const metadata: Metadata = {
  title: "Shared Enterprise Platform",
  description: "Learn about the cross-cutting platform foundation and feature-specific readiness gates.",
};

export default function PlatformPage() {
  return <EcosystemDestination area="platform" />;
}
