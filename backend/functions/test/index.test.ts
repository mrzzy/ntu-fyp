import { afterAll, beforeAll, describe, expect, it } from "vitest";
import firebaseFunctionsTest from "firebase-functions-test";
import { FeaturesList } from "firebase-functions-test/lib/features.js";
import { getFirestore } from "firebase-admin/firestore";
import { OpenRouter } from "@openrouter/sdk";
import { v4 as uuidv4 } from "uuid";
import { DB_COLLECTION, FIELD_ID, rotateOpenRouter } from "../src/index.js";

let firebaseTest: FeaturesList;

beforeAll(() => {
  // init firebase testing subsystem
  firebaseTest = firebaseFunctionsTest(
    {
      projectId: "ntu-fyp-broche",
    },
    ".keys/ntu-fyp-broche-bec5cd5ef349.json",
  );
});

describe("rotateOpenRouter", () => {
  it("should rotate the OpenRouter API key and delete the old key", async () => {
    const openRouter = new OpenRouter({
      apiKey: process.env.OPENROUTER_MANAGE_KEY,
    });
    const db = getFirestore();
    // uuid name avoids collisions with real credentials
    const testDocId = `test-${uuidv4()}`;
    const testDocRef = db.collection(DB_COLLECTION).doc(testDocId);

    try {
      // create test document for rotation
      await testDocRef.create({ [FIELD_ID]: "" });

      // perform rotation against the test document
      await rotateOpenRouter(
        db,
        openRouter,
        testDocId,
        `broche-test-${testDocId}`,
      );

      // rotation should have stored a new key hash
      const hash = (await testDocRef.get()).get(FIELD_ID) as string;
      expect(hash).toBeTruthy();

      // delete the rotated key so no orphan remains
      await openRouter.apiKeys.delete({ hash });
    } finally {
      // delete test document
      await testDocRef.delete();
    }
  });
});

afterAll(() => {
  firebaseTest.cleanup();
});
