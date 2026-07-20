import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  androidReleaseManifest,
} from "../.tmp-test/app_update.js";
import worker from "../.tmp-test/index.js";

const expectedReleaseNotesByVersionCode = new Map([
  [
    19,
    {
      zh: [
        "训练历史下载后会保存在本机，再次打开记录页可立即显示",
        "会员到期后仍可查看已下载记录，但不再刷新云端",
        "优化训练状态提示条的宽度、居中与运行状态颜色",
        "优化会员到期续订核验，避免短暂显示为非会员",
      ],
      en: [
        "Downloaded workout history is now cached and shown immediately when Records reopens",
        "Downloaded history remains available after Premium expires, while cloud refresh stops",
        "Improved workout status labels with adaptive width, centered content, and active colors",
        "Improved renewal verification at expiry to avoid briefly showing Premium as inactive",
      ],
    },
  ],
]);

const request = (query = "platform=android&locale=zh", method = "GET") =>
  worker.fetch(
    new Request(`https://worker.test/app-update?${query}`, { method }),
    {},
  );

test("app-update returns the localized Android release manifest", async () => {
  const response = await request();
  const expectedReleaseNotes = expectedReleaseNotesByVersionCode.get(19);

  assert.equal(response.status, 200);
  assert.notEqual(expectedReleaseNotes, undefined);
  assert.equal(
    response.headers.get("content-type"),
    "application/json; charset=utf-8",
  );
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.deepEqual(await response.json(), {
    schemaVersion: 1,
    platform: "android",
    locale: "zh",
    latest: {
      versionCode: 19,
      versionName: "0.3.16",
      releaseNotes: expectedReleaseNotes.zh,
    },
  });
});

test("app-update selects English and falls back unsupported locales", async () => {
  const english = await request("platform=android&locale=en-US");
  const fallback = await request("platform=android&locale=fr-FR");

  assert.equal(english.status, 200);
  assert.equal(fallback.status, 200);
  assert.equal((await english.json()).locale, "en");
  assert.equal((await fallback.json()).locale, "en");
  const plainEnglish = await (
    await request("platform=android&locale=en")
  ).json();
  const regionalEnglish = await (
    await request("platform=android&locale=en-GB")
  ).json();
  assert.deepEqual(plainEnglish, regionalEnglish);
  assert.deepEqual(
    plainEnglish.latest.releaseNotes,
    expectedReleaseNotesByVersionCode.get(19).en,
  );
});

test("app-update rejects missing and unsupported platforms", async () => {
  for (const query of ["locale=zh", "platform=ios&locale=zh"]) {
    const response = await request(query);
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), {
      error: "unsupported_platform",
    });
  }
});

test("app-update rejects non-GET methods with an Allow header", async () => {
  const response = await request("platform=android&locale=zh", "POST");

  assert.equal(response.status, 405);
  assert.equal(response.headers.get("allow"), "GET");
  assert.deepEqual(await response.json(), { error: "method_not_allowed" });
});

test("release manifest stays synchronized with pubspec version", async () => {
  const pubspec = await readFile(
    new URL("../../../pubspec.yaml", import.meta.url),
    "utf8",
  );
  const versionMatch = /^version:\s*([^+\s]+)\+(\d+)\s*$/m.exec(pubspec);

  assert.notEqual(versionMatch, null);
  assert.equal(androidReleaseManifest.versionName, versionMatch[1]);
  assert.equal(androidReleaseManifest.versionCode, Number(versionMatch[2]));
  const expectedReleaseNotes = expectedReleaseNotesByVersionCode.get(
    androidReleaseManifest.versionCode,
  );
  assert.notEqual(
    expectedReleaseNotes,
    undefined,
    `add independent release-note expectations for versionCode ${androidReleaseManifest.versionCode}`,
  );
  assert.deepEqual(androidReleaseManifest.releaseNotes, expectedReleaseNotes);
  for (const locale of ["zh", "en"]) {
    const notes = androidReleaseManifest.releaseNotes[locale];
    assert.ok(notes.length >= 1 && notes.length <= 6);
    for (const note of notes) {
      assert.equal(note, note.trim());
      assert.ok(note.length > 0 && note.length <= 160);
    }
  }
});
