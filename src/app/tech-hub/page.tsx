import type { Metadata } from "next";
import EcosystemDestination from "../ecosystem-destination";

export const metadata: Metadata = {
  title: "Tech Hub & Advertising Engine",
  description:
    "Editorial publishing, SEO and advertising workflows are planned, not enabled.",
};

export default function TechHubPage() {
  return <EcosystemDestination area="tech-hub" />;
}
