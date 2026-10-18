import assert from "node:assert/strict";
import test from "node:test";
import { reduceDshSignal } from "../src/index.js";

test("maps approval requests to the stable approval state", () => {
  assert.equal(reduceDshSignal({ kind: "approval-required" }), "waiting_approval");
});

test("maps disconnects to offline", () => {
  assert.equal(reduceDshSignal({ kind: "disconnected" }), "offline");
});
