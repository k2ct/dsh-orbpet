import assert from "node:assert/strict";
import test from "node:test";
import { EventEmitter } from "node:events";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import apply from "../lib/index.js";

class FakeContext extends EventEmitter {
  logger = {
    info() {},
    warning() {},
    error() {},
  };
}

test("supervises one child and stops it on DSH dispose", async () => {
  const directory = await mkdtemp(join(tmpdir(), "dsh-companion-plugin-"));
  const childScript = join(directory, "fake-companion.js");
  await writeFile(childScript, "setInterval(() => {}, 1000);\n", "utf8");

  const ctx = new FakeContext();
  const service = apply(ctx, { executable: process.execPath, executableArgs: [childScript], closeWithDsh: true });
  assert.ok(service);
  assert.equal(service.status().running, true);
  const pid = service.status().pid;

  service.start();
  assert.equal(service.status().pid, pid, "start must not create a duplicate child");

  ctx.emit("dispose");
  await new Promise((resolve) => setTimeout(resolve, 300));
  assert.equal(service.status().running, false);
});

test("does nothing when disabled", () => {
  const ctx = new FakeContext();
  assert.equal(apply(ctx, { enabled: false }), undefined);
});
