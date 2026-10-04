// Runs the Worker's App Store credential check from the command line, with
// the key taken from the environment (CI secrets). Prints only statuses.
import { appleCheck } from "./entitlement.js";

const env = {
  APPLE_ASC_KEY: process.env.APPLE_ASC_KEY,
  APPLE_ASC_KEY_ID: process.env.APPLE_ASC_KEY_ID,
  APPLE_ASC_ISSUER_ID: process.env.APPLE_ASC_ISSUER_ID,
  ENTITLEMENT_SIGNING_KEY: "unused-here",
};
const result = await appleCheck(env);
console.log(JSON.stringify(result));
process.exit(result.ok ? 0 : 1);
