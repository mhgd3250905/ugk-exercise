import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  androidReleaseManifest,
} from "../.tmp-test/app_update.js";
import worker from "../.tmp-test/index.js";

const expectedReleaseNotesByVersionCode = new Map([
  [
    24,
    {
      zh: [
        "稳定性：本地记录损坏不再导致所有训练页面无法打开，单条异常训练也不再阻塞云端同步",
        "账号：登录不再因购买服务瞬时网络错误而误报失败，购买/恢复会自动重试连接",
        "体验：训练姿态剪影更清晰，排行榜积分明细改为水印式展开",
      ],
      en: [
        "Stability: corrupted local records no longer block all workout screens, and one malformed session no longer stalls cloud sync",
        "Account: sign-in no longer reports failure when the purchase service hits a brief network blip; purchase/restore now retries the link",
        "Experience: clearer pose silhouette overlay and a watermark-style leaderboard points breakdown",
      ],
    },
  ],
  [
    23,
    {
      zh: [
        "近距离识别优化：距离过近时提示退后，减少俯卧撑底部漏记",
        "训练排行榜：点击有分用户可展开查看标准/窄距次数明细，训练后积分即时刷新",
        "体验修复：英文语音播报速率、本地记录存储稳定性改进",
      ],
      en: [
        "Closer-range recognition: prompts you to step back when too close, reducing missed reps at the bottom of a pushup",
        "Leaderboard: tap a ranked user to see their standard vs narrow rep breakdown; points refresh right after a workout",
        "Fixes: English voice playback rate and local record storage stability",
      ],
    },
  ],
  [
    22,
    {
      zh: [
        "训练启停与切相机更稳定，修复快速操作导致的相机或资源泄漏",
        "会员与排行榜网络请求增加超时保护，弱网下不再无限等待",
        "强化管理台写入安全，所有操作需独立意图校验",
      ],
      en: [
        "Workout start, stop, and camera switch are more robust, fixing leaks from rapid taps",
        "Membership and leaderboard requests now time out instead of waiting forever on weak networks",
        "Hardened admin write safety with independent intent verification on every action",
      ],
    },
  ],
  [
    21,
    {
      zh: [
        "姿态丢失时清晰提示“姿势已中断”并保留已完成计数",
        "姿态重新出现时平稳回到训练，准备态与训练态切换更稳定",
        "修复会员管理台在 Access 浏览器下写入失败的问题",
        "新增会员运营管理台，受 Cloudflare Access 保护",
      ],
      en: [
        "Clear “pose lost” prompt now preserves your completed count",
        "Smoother recovery and transitions between preparation and training states",
        "Fixed membership admin write failures under Access-authenticated browsers",
        "Added a membership operations dashboard, protected by Cloudflare Access",
      ],
    },
  ],
  [
    20,
    {
      zh: [
        "适配 Android 15 无边框显示，内容会避开系统栏和手势区域",
        "优化平板、折叠屏和横屏布局，宽屏训练采用双栏显示",
        "移除大屏方向与尺寸限制，支持自由旋转和窗口调整",
        "升级 Android 构建基础，提高新系统兼容性",
      ],
      en: [
        "Added Android 15 edge-to-edge support with safe system and gesture insets",
        "Improved tablet, foldable, and landscape layouts with a two-pane wide workout view",
        "Removed large-screen orientation and resize restrictions for adaptive windows",
        "Updated the Android build foundation for newer platform compatibility",
      ],
    },
  ],
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
  const expectedReleaseNotes = expectedReleaseNotesByVersionCode.get(
    androidReleaseManifest.versionCode,
  );

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
      versionCode: androidReleaseManifest.versionCode,
      versionName: androidReleaseManifest.versionName,
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
    expectedReleaseNotesByVersionCode.get(androidReleaseManifest.versionCode).en,
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
