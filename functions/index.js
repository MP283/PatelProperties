const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const {google} = require("googleapis");
const serviceAccount = require("./service-account.json");

admin.initializeApp();

setGlobalOptions({region: "asia-south1"});

const SHEET_ID = "18sCngqIXavQWdYBJKAl1TGS43-0_Y-MYr8TGVjfK3Zs";
const SHEET_TAB = "Token_2026";

// ─── Helper: Google Sheets auth ────────────────────────────────────────────
function getSheetsClient() {
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: ["https://www.googleapis.com/auth/spreadsheets"],
  });
  return google.sheets({version: "v4", auth});
}

// ─── Helper: safe date formatter ───────────────────────────────────────────
function formatDate(value) {
  if (!value) return "";
  if (value._seconds) return new Date(value._seconds * 1000).toLocaleDateString("en-IN");
  if (typeof value.toDate === "function") return value.toDate().toLocaleDateString("en-IN");
  if (typeof value === "string") return value;
  return String(value);
}

// ─── Helper: build row array from Firestore data ───────────────────────────
function buildRow(data, docId) {
  return [
    data.tokenNumber || docId,
    data.ownerName || "",
    data.tenantName || "",
    data.propertyName || "",
    formatDate(data.startDate),
    formatDate(data.endDate),
    data.stampDuty || "",
    data.ownerChargesPaid ? "Yes" : "No",
    data.tenantChargesPaid ? "Yes" : "No",
    data.status || "",
    data.cost || "",
    data.costPerParty || "",
    data.tenantPhone || "",
    data.tenantEmail || "",
    data.ownerPhone || "",
    data.ownerEmail || "",
    data.durationMonths || "",
  ];
}

const HEADERS = [
  "Token No", "Owner Name", "Tenant Name", "Property", "Start Date", "End Date",
  "Stamp Duty", "Owner Charges Paid", "Tenant Charges Paid", "Status", "Cost",
  "Cost Per Party", "Tenant Phone", "Tenant Email", "Owner Phone", "Owner Email",
  "Duration (Months)",
];

// ─── Helper: send to all tokens split by platform ──────────────────────────
// ─── Helper: send to all tokens split by platform ──────────────────────────
async function sendToAllTokens(title, body) {
  const db = admin.firestore();

  // ── Kill switch ──────────────────────────────────────────
  const settingsSnap = await db.collection("settings").doc("notifications").get();
  if (settingsSnap.exists && settingsSnap.data().enabled === false) {
    console.log("🔕 Notifications are disabled via kill switch — skipping.");
    return;
  }

  const snapshot = await db.collection("fcm_tokens").get();

  const webTokens = [];
  const nativeTokens = [];

  snapshot.forEach((doc) => {
    const data = doc.data();
    if (!data.token) return;
    // ✅ Check by doc ID prefix instead of exact "web" match
    if (doc.id.startsWith("web_")) webTokens.push(data.token);
    else nativeTokens.push(data.token);
  });

  if (webTokens.length === 0 && nativeTokens.length === 0) {
    console.warn("No FCM tokens found — nobody to notify.");
    return;
  }

  const sends = [];

  if (webTokens.length > 0) {
    sends.push(admin.messaging().sendEachForMulticast({
      notification: {title, body},
      webpush: {
        notification: {
          title,
          body,
          icon: "/icons/Icon-192.png",
        },
      },
      tokens: webTokens,
    }));
  }

  if (nativeTokens.length > 0) {
    sends.push(admin.messaging().sendEachForMulticast({
      notification: {title, body},
      android: {priority: "high"},
      tokens: nativeTokens,
    }));
  }

  const results = await Promise.all(sends);
  results.forEach((response) => {
    console.log(
        "Sent: " + response.successCount + " success, " +
        response.failureCount + " failed",
    );
  });
}

// ─── 🏠 New Property ───────────────────────────────────────────────────────
exports.notifyNewProperty = onDocumentCreated(
    "properties/{propertyId}",
    async (event) => {
      const data = event.data.data();
      const projectName = data.projectName || "Unknown Project";
      const bhk = data.bhk || "";
      const price = data.price || "";

      await sendToAllTokens(
          "New Property Added",
          bhk + " BHK • " + projectName + " • ₹" + price,
      );
    },
);

// ─── 👤 New Client ─────────────────────────────────────────────────────────
exports.notifyNewClient = onDocumentCreated(
    "clients/{clientId}",
    async (event) => {
      const data = event.data.data();
      const name = data.clientName || "Unknown Client";
      const phone = data.contactNumber || "";
      const dealType = data.dealType || "";

      await sendToAllTokens(
          "New Client Added",
          name + " • " + phone + " • " + dealType,
      );
    },
);

// ─── 📅 New Visit ──────────────────────────────────────────────────────────
exports.notifyNewVisit = onDocumentCreated(
    "visits/{visitId}",
    async (event) => {
      const data = event.data.data();
      const propertyId = data.propertyId || null;
      const clientId = data.clientId || null;
      const visitDate = data.Date || "";

      const db = admin.firestore();
      const [propertySnap, clientSnap] = await Promise.all([
        propertyId ?
          db.collection("properties").doc(propertyId).get() :
          Promise.resolve(null),
        clientId ?
          db.collection("clients").doc(clientId).get() :
          Promise.resolve(null),
      ]);

      let projectName = "Unknown Property";
      let bhk = "";
      let clientName = "Unknown Client";

      if (propertySnap && propertySnap.exists) {
        const property = propertySnap.data();
        projectName = property.projectName || "Unknown Property";
        bhk = property.bhk || "";
      }

      if (clientSnap && clientSnap.exists) {
        const client = clientSnap.data();
        clientName = client.clientName || "Unknown Client";
      }

      await sendToAllTokens(
          "New Visit Scheduled",
          clientName + " • " + bhk + " BHK " + projectName + " • " + visitDate,
      );
    },
);

// ─── 📄 Sync New Rent Agreement → Google Sheets ────────────────────────────
exports.syncRentAgreementToSheets = onDocumentCreated(
    "rentAgreements/{agreementId}",
    async (event) => {
      const data = event.data.data();
      const docId = event.params.agreementId;
      const row = buildRow(data, docId);

      try {
        const sheets = getSheetsClient();

        // ✅ Auto-add header row if sheet is empty
        const existing = await sheets.spreadsheets.values.get({
          spreadsheetId: SHEET_ID,
          range: `${SHEET_TAB}!A1:A1`,
        });

        const isEmpty = !existing.data.values || existing.data.values.length === 0;

        if (isEmpty) {
          await sheets.spreadsheets.values.update({
            spreadsheetId: SHEET_ID,
            range: `${SHEET_TAB}!A1`,
            valueInputOption: "RAW",
            requestBody: {values: [HEADERS]},
          });
        }

        // ✅ Append new row
        await sheets.spreadsheets.values.append({
          spreadsheetId: SHEET_ID,
          range: `${SHEET_TAB}!A1`,
          valueInputOption: "RAW",
          insertDataOption: "INSERT_ROWS",
          requestBody: {values: [row]},
        });

        console.log("✅ Rent agreement synced to Sheets:", data.tokenNumber || docId);

        // await sendToAllTokens(
        //     "New Rent Agreement",
        //     "Token " + (data.tokenNumber || "") + " • " +
        //     (data.tenantName || "Tenant") + " • " +
        //     (data.propertyName || "Property"),
        // );
      } catch (err) {
        console.error("❌ Sheets sync failed:", err);
      }
    },
);

// ─── 📄 Update Rent Agreement → Google Sheets ──────────────────────────────
exports.updateRentAgreementInSheets = onDocumentUpdated(
    "rentAgreements/{agreementId}",
    async (event) => {
      const data = event.data.after.data();
      const docId = event.params.agreementId;
      const tokenNumber = data.tokenNumber || docId;
      const row = buildRow(data, docId);

      try {
        const sheets = getSheetsClient();

        // ✅ Find the row with matching token number in column A
        const response = await sheets.spreadsheets.values.get({
          spreadsheetId: SHEET_ID,
          range: `${SHEET_TAB}!A:A`,
        });

        const columnA = response.data.values || [];
        const rowIndex = columnA.findIndex(
            (r) => r[0] && r[0].toString() === tokenNumber.toString(),
        );

        if (rowIndex === -1) {
          // ✅ Not found — append as new row (edge case safety)
          console.warn("⚠️ Token not found in sheet, appending as new row:", tokenNumber);
          await sheets.spreadsheets.values.append({
            spreadsheetId: SHEET_ID,
            range: `${SHEET_TAB}!A1`,
            valueInputOption: "RAW",
            insertDataOption: "INSERT_ROWS",
            requestBody: {values: [row]},
          });
        } else {
          // ✅ Found — update in place
          const sheetRow = rowIndex + 1;
          await sheets.spreadsheets.values.update({
            spreadsheetId: SHEET_ID,
            range: `${SHEET_TAB}!A${sheetRow}`,
            valueInputOption: "RAW",
            requestBody: {values: [row]},
          });
          console.log("✅ Rent agreement updated in Sheets — row " + sheetRow + ", token:", tokenNumber);
        }
      } catch (err) {
        console.error("❌ Sheets update failed:", err);
      }
    },
);
