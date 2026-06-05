import chalk from "chalk";
import { confirm } from "@inquirer/prompts";
import { registryGet, registryAdd, type SandboxEntry } from "../lib/registry.js";
import { isSandboxRunning, destroySandbox } from "../lib/sandbox.js";
import { snapshotCommand } from "./snapshot.js";
import { onboardCommand } from "./onboard.js";
import { writeFileSync, readFileSync, existsSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { HERMESSHELL_HOME } from "../lib/constants.js";

interface RebuildOptions {
  yes?: boolean;
  verbose?: boolean;
}

const STASH_FILE = join(HERMESSHELL_HOME, ".rebuild-stash.json");

function stashRegistryEntry(name: string, entry: SandboxEntry): void {
  writeFileSync(STASH_FILE, JSON.stringify({ name, entry }, null, 2), { mode: 0o600 });
}

function clearStash(): void {
  try { unlinkSync(STASH_FILE); } catch { /* already gone */ }
}

/**
 * Restore a stashed registry entry. Called from the exit handler (sync)
 * when the rebuild is interrupted between destroy and successful recreate.
 * registryAdd is async, so we write the file directly here.
 */
function restoreStashedEntry(): void {
  if (!existsSync(STASH_FILE)) return;
  try {
    const { name, entry } = JSON.parse(readFileSync(STASH_FILE, "utf-8"));
    const regPath = join(HERMESSHELL_HOME, "sandboxes.json");
    if (!existsSync(regPath)) return;
    const registry = JSON.parse(readFileSync(regPath, "utf-8"));
    if (registry.sandboxes[name]) return; // onboard already re-created it
    registry.sandboxes[name] = entry;
    if (!registry.default) registry.default = name;
    writeFileSync(regPath, JSON.stringify(registry, null, 2));
    console.log(chalk.yellow(`  Registry entry for '${name}' restored from stash.`));
    console.log(chalk.yellow(`  Re-run: hermesshell ${name} rebuild`));
  } catch { /* best effort */ }
}

export async function rebuildCommand(name: string, opts: RebuildOptions): Promise<void> {
  const entry = await registryGet(name);
  if (!entry) {
    console.error(chalk.red(`Sandbox '${name}' not found in registry.`));
    process.exit(1);
  }

  // Propagate provider/model/tier from the stashed registry entry so the
  // non-interactive `onboardCommand` call below has what it needs. Without
  // these, onboard falls through to `process.env.HERMESSHELL_PROVIDER`
  // (onboard.ts:217), finds it unset, and bails with "HERMESSHELL_PROVIDER
  // is required in non-interactive mode" — leaving the sandbox destroyed
  // and the user stuck running rebuild with `HERMESSHELL_PROVIDER=... \
  // HERMESSHELL_MODEL=...` hand-set from the registry. The entry already
  // has these values; the bug was just that nothing plumbed them through.
  //
  // Existing environment vars (e.g. set by the user) take precedence so
  // they can still override the registry on a one-off basis.
  if (entry.provider && !process.env.HERMESSHELL_PROVIDER) {
    process.env.HERMESSHELL_PROVIDER = entry.provider;
  }
  if (entry.model && !process.env.HERMESSHELL_MODEL) {
    process.env.HERMESSHELL_MODEL = entry.model;
  }
  if (entry.tier && !process.env.HERMESSHELL_POLICY_TIER) {
    process.env.HERMESSHELL_POLICY_TIER = entry.tier;
  }

  console.log(chalk.bold(`Rebuilding sandbox: ${name}`));
  console.log(chalk.dim("  This will: snapshot → destroy → recreate → restore"));
  console.log("");

  if (!opts.yes) {
    const confirmed = await confirm({
      message: `Rebuild sandbox '${name}'?`,
      default: true,
    });
    if (!confirmed) {
      console.log("Aborted.");
      return;
    }
  }

  // Step 1: Snapshot
  const running = await isSandboxRunning(name);
  if (running) {
    if (opts.verbose) console.log(chalk.dim("  Step 1: Creating snapshot..."));
    await snapshotCommand.create(name);
  } else {
    console.log(chalk.yellow("  Sandbox not running — skipping snapshot."));
  }

  // Step 2: Destroy
  // Stash the registry entry before destroy so it survives if recreate
  // fails (onboardCommand calls process.exit on failure, so we can't
  // catch the error — the exit handler restores the stash instead).
  stashRegistryEntry(name, entry);
  const exitHandler = () => restoreStashedEntry();
  process.on("exit", exitHandler);

  if (opts.verbose) console.log(chalk.dim("  Step 2: Destroying sandbox..."));
  if (running) {
    await destroySandbox(name);
  }

  // Step 3: Recreate via onboard --resume
  if (opts.verbose) console.log(chalk.dim("  Step 3: Recreating sandbox..."));
  await onboardCommand({
    resume: true,
    agent: name,
    recreateSandbox: false,
    nonInteractive: true,
    yesIAcceptThirdPartySoftware: true,
  });

  // Recreate succeeded — disarm the safety net
  process.removeListener("exit", exitHandler);
  clearStash();

  // Step 4: Restore
  if (running) {
    if (opts.verbose) console.log(chalk.dim("  Step 4: Restoring snapshot..."));
    await snapshotCommand.restore(name);
  }

  console.log("");
  console.log(chalk.green(`✓ Sandbox '${name}' rebuilt successfully.`));
}
