declare module "braces" {
  export default function braces(
    pattern: string,
    options?: Record<string, unknown>,
  ): string[];
}
