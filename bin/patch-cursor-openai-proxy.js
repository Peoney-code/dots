#!/usr/bin/env bun
/**
 * Patches cursor-openai-api dist/proxy.js for avante:
 * - drop spurious "Connect error internal: Error" from chat stream
 * - hide model thinking (no <think> in UI)
 */
import { readFileSync, writeFileSync } from "node:fs";

const proxyPath = process.argv[2];
if (!proxyPath) {
  console.error("usage: patch-cursor-openai-proxy.js /path/to/dist/proxy.js");
  process.exit(1);
}

let src = readFileSync(proxyPath, "utf8");
if (src.includes("/* avante-proxy-patch */")) {
  console.log("proxy.js already patched");
  process.exit(0);
}

const oldEndError =
  "if (endError) {\n                            sendSSE(makeChunk({ content: `\\n[Error: ${endError.message}]` }));";
const newEndError = `if (endError) {
                            /* avante-proxy-patch */
                            const benign = endError.message === "Connect error internal: Error";
                            if (!benign) {
                              console.error("[cursor-openai-api]", endError.message);
                              sendSSE(makeChunk({ content: \`\\n[Error: \${endError.message}]\` }));
                            }`;

const count = (src.match(/sendSSE\(makeChunk\(\{ content: `\\n\[Error: \$\{endError\.message\}\]` \}\)\)/g) || []).length;
if (count === 0) {
  console.error("proxy.js format changed — patch not applied");
  process.exit(1);
}
src = src.replaceAll(oldEndError, newEndError);

const oldThinking = `(text, isThinking) => {
                            if (isThinking) {
                                if (!state.thinkingActive) {
                                    state.thinkingActive = true;
                                    sendSSE(makeChunk({ role: "assistant", content: "<think>" }));
                                }
                                sendSSE(makeChunk({ content: text }));
                            }
                            else {
                                if (state.thinkingActive) {
                                    state.thinkingActive = false;
                                    sendSSE(makeChunk({ content: "</think>" }));
                                }
                                sendSSE(makeChunk({ content: text }));
                            }
                        }`;

const newThinking = `(text, isThinking) => {
                            /* avante-proxy-patch: hide thinking stream */
                            if (isThinking) {
                                state.thinkingActive = true;
                                return;
                            }
                            state.thinkingActive = false;
                            sendSSE(makeChunk({ content: text }));
                        }`;

const thinkingCount = (src.match(/<think>/g) || []).length;
if (thinkingCount < 2) {
  console.error("thinking handler format changed — partial patch");
} else {
  src = src.replaceAll(oldThinking, newThinking);
  // tool-resume path uses slightly different formatting
  src = src.replaceAll(
    `(text, isThinking) => {
                            if (isThinking) {
                                if (!state.thinkingActive) {
                                    state.thinkingActive = true;
                                    sendSSE(makeChunk({ role: "assistant", content: "<think>" }));
                                }
                                sendSSE(makeChunk({ content: text }));
                            }
                            else {
                                if (state.thinkingActive) {
                                    state.thinkingActive = false;
                                    sendSSE(makeChunk({ content: "</think>" }));
                                }
                                sendSSE(makeChunk({ content: text }));
                            }
                        }, (exec) => {`,
    `(text, isThinking) => {
                            if (isThinking) { state.thinkingActive = true; return; }
                            state.thinkingActive = false;
                            sendSSE(makeChunk({ content: text }));
                        }, (exec) => {`,
  );
}

writeFileSync(proxyPath, src);
console.log("Patched", proxyPath);
