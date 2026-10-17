import type { Metadata } from "next";
import EcosystemDestination from "../ecosystem-destination";

export const metadata: Metadata = {
  title: "Web Hosting & Deployment",
  description: "Hosting provisioning and billing are planned, not operational.",
};

export default function HostingPage() {
  return <EcosystemDestination area="hosting" />;
}
