export default function Loading() {
  return (
    <main
      className="page-shell"
      aria-busy="true"
      aria-live="polite"
      style={{ paddingBlock: "4rem" }}
    >
      <p className="eyebrow">Loading</p>
      <h1 style={{ fontSize: "clamp(2rem, 5vw, 4rem)" }}>
        Getting things ready…
      </h1>
    </main>
  );
}
