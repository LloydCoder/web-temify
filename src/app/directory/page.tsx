import type { Metadata } from "next";
import EcosystemDestination from "../ecosystem-destination";

export const metadata: Metadata = {
  title: "Tech Directory Hub",
  description:
    "Explore the current directory preview; submissions and paid placements are not live.",
  alternates: { canonical: "/directory" },
};

export default function DirectoryPage() {
  return <EcosystemDestination area="directory" />;
}
