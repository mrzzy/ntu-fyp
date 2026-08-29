import { setGlobalOptions, logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineString } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { OpenRouter } from "@openrouter/sdk";

// collection for storing credentials
export const DB_COLLECTION = "credentials";
export const FIELD_TOKEN = "token";
export const FIELD_ID = "id";

// Configuration parameters for API token management
const OPENROUTER_MANAGE_KEY = defineString("OPENROUTER_MANAGE_KEY");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 1 });

initializeApp();

/**
 * Rotates the OpenRouter API key stored in Firestore and deletes the old key.
 * @param db Firestore database instance
 * @param openRouter OpenRouter client instance
 * @param docId Document ID for storing the API key (default: "openrouter")
 * @param keyName Name assigned to the newly created API key (default: "Broche")
 */
export async function rotateOpenRouter(
  db: FirebaseFirestore.Firestore,
  openRouter: OpenRouter,
  docId: string = "openrouter",
  keyName: string = "Broche",
) {
  const docRef = db.collection(DB_COLLECTION).doc(docId);
  const doc = await docRef.get();
  const oldHash = doc.exists ? (doc.get(FIELD_ID) as string) : "";

  // create new api key
  const newKey = await openRouter.apiKeys.create({
    requestBody: {
      name: keyName,
    },
  });

  // save new api key to firestore
  await docRef.set({
    [FIELD_TOKEN]: newKey.key,
    [FIELD_ID]: newKey.data.hash,
    rotatedOn: FieldValue.serverTimestamp(),
  });
  logger.debug("Created new OpenRouter API key", {
    newHash: newKey.data.hash,
  });

  // delete old api key
  if (oldHash) {
    await openRouter.apiKeys.delete({
      hash: oldHash,
    });
    logger.debug("Deleted old OpenRouter API key", {
      newHash: oldHash,
    });
  } else {
    logger.warn("No old OpenRouter API key found to delete");
  }

  logger.info("Rotated OpenRouter API key", {
    oldHash: oldHash,
    newHash: newKey.data.hash,
  });
}

/**
 * Scheduled function that rotates API tokens daily at midnight
 * Automatically creates a scheduler job and HTTP function on deployment
 */
// scheduled every day at midnight.
exports.rotateApiTokens = onSchedule("0 0 * * *", async () => {
  // Initialize Firebase Admin SDK & Firestore
  const db = getFirestore();

  // Init openrouter client
  const openRouter = new OpenRouter({
    apiKey: OPENROUTER_MANAGE_KEY.value(),
  });

  logger.info("Starting scheduled API token rotation");
  await rotateOpenRouter(db, openRouter);
  logger.info("Scheduled API token rotation finished");
});
