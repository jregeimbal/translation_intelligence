import type {
  FullConfig,
  FullResult,
  Reporter,
  Suite,
  TestCase,
  TestResult,
} from "@playwright/test/reporter";
import * as fs from "fs";
import * as path from "path";

/**
 * Custom Playwright reporter that summarises pass / fail results and links
 * every captured screenshot.
 *
 * Output is written to stdout as a human-readable summary and to a JSON file
 * at `<outputDir>/e2e-summary.json`.
 */
export default class ScreenshotReporter implements Reporter {
  private passed: TestCase[] = [];
  private failed: { test: TestCase; result: TestResult }[] = [];
  private screenshots: { test: string; path: string }[] = [];
  private outputDir = "";

  onBegin(_config: FullConfig, _suite: Suite): void {
    this.outputDir = _config.projects[0]?.outputDir ?? "test-results";
  }

  onTestEnd(test: TestCase, result: TestResult): void {
    if (result.status === "passed") {
      this.passed.push(test);
    } else if (result.status === "failed" || result.status === "timedOut") {
      this.failed.push({ test, result });
    }

    for (const attachment of result.attachments) {
      if (
        attachment.contentType.startsWith("image/") &&
        attachment.path
      ) {
        this.screenshots.push({
          test: test.title,
          path: attachment.path,
        });
      }
    }
  }

  onEnd(result: FullResult): void {
    const total = this.passed.length + this.failed.length;
    const status = this.failed.length === 0 ? "PASS" : "FAIL";

    console.log("\n========================================");
    console.log(`  E2E Summary: ${status}`);
    console.log(`  Total: ${total}  Passed: ${this.passed.length}  Failed: ${this.failed.length}`);
    console.log("========================================\n");

    if (this.failed.length > 0) {
      console.log("Failures:");
      for (const { test, result: res } of this.failed) {
        const firstError = res.errors[0];
        const errorSnippet = firstError?.message?.split("\n")[0] ?? "unknown error";
        console.log(`  ✗ ${test.title}`);
        console.log(`    ${errorSnippet}`);
      }
      console.log("");
    }

    if (this.screenshots.length > 0) {
      console.log("Screenshots:");
      for (const s of this.screenshots) {
        const relativePath = path.relative(process.cwd(), s.path);
        console.log(`  📸 [${s.test}] ${relativePath}`);
      }
      console.log("");
    }

    // Write a machine-readable summary to disk.
    const summary = {
      status,
      total,
      passed: this.passed.length,
      failed: this.failed.length,
      failures: this.failed.map(({ test, result: res }) => ({
        title: test.title,
        error: res.errors[0]?.message?.split("\n")[0] ?? "unknown",
      })),
      screenshots: this.screenshots.map((s) => ({
        test: s.test,
        path: s.path,
      })),
    };

    const outPath = path.join(this.outputDir, "e2e-summary.json");
    fs.mkdirSync(this.outputDir, { recursive: true });
    fs.writeFileSync(outPath, JSON.stringify(summary, null, 2));
    console.log(`Summary written to ${outPath}\n`);
  }
}
