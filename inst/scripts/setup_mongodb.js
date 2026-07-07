// =============================================================================
// metasurvey — MongoDB Setup Script
// =============================================================================
//
// Creates collections (users, recipes, workflows, indicators) with JSON Schema validation,
// and builds all required indexes.
//
// IMPORTANT: On MongoDB Atlas free/shared tier the user typically lacks collMod
// permissions. If collections already exist and you need to update the schema,
// drop them first (the seed script will repopulate the data):
//
//   db.recipes.drop();
//   db.workflows.drop();
//
// Usage:
//   mongosh "mongodb+srv://user:pass@cluster.mongodb.net/metasurvey" \
//     inst/scripts/setup_mongodb.js
//
// After setup, seed data with:
//   METASURVEY_MONGO_URI="mongodb+srv://..." Rscript inst/scripts/seed_ech_recipes.R
//
// =============================================================================

print("=== metasurvey MongoDB Setup ===");
print("Database: " + db.getName());

// ---------------------------------------------------------------------------
// 1. Create collections with JSON Schema validation
// ---------------------------------------------------------------------------

// --- users ---
try {
  db.createCollection("users", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["name", "email", "password_hash", "user_type", "created_at"],
        properties: {
          name:          { bsonType: "string", minLength: 1 },
          email:         { bsonType: "string", pattern: "^.+@.+\\..+$" },
          password_hash: { bsonType: "string", minLength: 64, maxLength: 64 },
          user_type:     { enum: ["individual", "institutional_member", "institution"] },
          institution:   { bsonType: ["string", "null"] },
          affiliation:   { bsonType: ["string", "null"] },
          url:           { bsonType: ["string", "null"] },
          verified:      { bsonType: "bool" },
          review_status: { enum: ["approved", "pending", "rejected"] },
          reviewed_by:   { bsonType: ["string", "null"] },
          reviewed_at:   { bsonType: ["string", "null"] },
          created_at:    { bsonType: "string" }
        }
      }
    }
  });
  print("[OK] users");
} catch (e) {
  if (e.codeName === "NamespaceExists") {
    print("[SKIP] users — already exists");
  } else {
    print("[ERROR] users: " + e.message);
  }
}

// --- recipes ---
try {
  db.createCollection("recipes", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["name", "user", "survey_type"],
        properties: {
          name:        { bsonType: "string", minLength: 1 },
          user:        { bsonType: "string" },
          survey_type: { enum: ["ech", "eaii", "eph", "eai"] },
          edition:     { bsonType: ["string", "array"] },
          description: { bsonType: "string" },
          topic:       { enum: ["labor_market", "income", "education", "health", "demographics", "housing", null] },
          doi:         { bsonType: ["string", "null"] },
          version:     { bsonType: "string" },
          downloads:   { bsonType: ["int", "double"], minimum: 0 },
          steps:       { bsonType: "array" },
          depends_on:  { bsonType: "array" },
          depends_on_recipes: { bsonType: "array" },
          data_source: { bsonType: ["object", "null"] },
          categories:  { bsonType: "array" },
          certification: {
            bsonType: ["object", "null"],
            properties: {
              level:        { enum: ["community", "reviewed", "official"] },
              certified_at: { bsonType: ["string", "null"] },
              certified_by: { bsonType: ["object", "null"] },
              notes:        { bsonType: ["string", "null"] }
            }
          },
          user_info: { bsonType: ["object", "null"] },
          doc:       { bsonType: ["object", "null"] }
        }
      }
    }
  });
  print("[OK] recipes");
} catch (e) {
  if (e.codeName === "NamespaceExists") {
    print("[SKIP] recipes — already exists (drop first to update schema)");
  } else {
    print("[ERROR] recipes: " + e.message);
  }
}

// --- workflows ---
try {
  db.createCollection("workflows", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["name", "user", "survey_type"],
        properties: {
          name:            { bsonType: "string", minLength: 1 },
          user:            { bsonType: "string" },
          survey_type:     { enum: ["ech", "eaii", "eph", "eai"] },
          edition:         { bsonType: ["string", "array"] },
          description:     { bsonType: "string" },
          version:         { bsonType: "string" },
          doi:             { bsonType: ["string", "null"] },
          downloads:       { bsonType: ["int", "double"], minimum: 0 },
          created_at:      { bsonType: "string" },
          estimation_type: { bsonType: ["string", "array"] },
          recipe_ids:      { bsonType: "array" },
          calls:           { bsonType: "array" },
          call_metadata:   { bsonType: "array" },
          categories:      { bsonType: "array" },
          certification:   { bsonType: ["object", "null"] },
          user_info:       { bsonType: ["object", "null"] }
        }
      }
    }
  });
  print("[OK] workflows");
} catch (e) {
  if (e.codeName === "NamespaceExists") {
    print("[SKIP] workflows — already exists (drop first to update schema)");
  } else {
    print("[ERROR] workflows: " + e.message);
  }
}

// ---------------------------------------------------------------------------
// 2. Create indexes
// ---------------------------------------------------------------------------
print("\n--- Indexes ---");

db.users.createIndex({ "email": 1 }, { unique: true });

db.recipes.createIndex({ "id": 1 },                  { unique: true, sparse: true });
db.recipes.createIndex({ "user": 1 });
db.recipes.createIndex({ "survey_type": 1 });
db.recipes.createIndex({ "topic": 1 });
db.recipes.createIndex({ "downloads": -1 });
db.recipes.createIndex({ "certification.level": 1 });
db.recipes.createIndex({ "survey_type": 1, "edition": 1 });
db.recipes.createIndex(
  { "name": "text", "description": "text", "topic": "text" },
  { name: "recipes_text_search" }
);

db.workflows.createIndex({ "id": 1 },                    { unique: true, sparse: true });
db.workflows.createIndex({ "user": 1 });
db.workflows.createIndex({ "survey_type": 1 });
db.workflows.createIndex({ "recipe_ids": 1 });
db.workflows.createIndex({ "downloads": -1 });
db.workflows.createIndex({ "survey_type": 1, "edition": 1 });
db.workflows.createIndex(
  { "name": "text", "description": "text" },
  { name: "workflows_text_search" }
);

// --- anda_variables ---
try {
  db.createCollection("anda_variables", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["survey_type", "name", "label"],
        properties: {
          survey_type:       { bsonType: "string" },
          name:              { bsonType: "string" },
          label:             { bsonType: "string" },
          type:              { enum: ["discrete", "continuous", "unknown"] },
          value_labels:      { bsonType: ["object", "null"] },
          description:       { bsonType: ["string", "null"] },
          source_edition:    { bsonType: "string" },
          source_catalog_id: { bsonType: ["int", "double"] }
        }
      }
    }
  });
  print("[OK] anda_variables");
} catch (e) {
  if (e.codeName === "NamespaceExists") {
    print("[SKIP] anda_variables — already exists");
  } else {
    print("[ERROR] anda_variables: " + e.message);
  }
}

db.anda_variables.createIndex({ survey_type: 1, name: 1 }, { unique: true });
db.anda_variables.createIndex({ survey_type: 1 });

// --- indicators ---
try {
  db.createCollection("indicators", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["name", "workflow_id", "value", "user"],
        properties: {
          id:               { bsonType: "string" },
          name:             { bsonType: "string", minLength: 1 },
          description:      { bsonType: ["string", "null"] },
          recipe_id:        { bsonType: ["string", "null"] },
          workflow_id:      { bsonType: "string" },
          survey_type:      { bsonType: ["string", "null"] },
          edition:          { bsonType: ["string", "array", "null"] },
          estimation_type:  { bsonType: ["string", "null"] },
          stat:             { bsonType: ["string", "null"] },
          value:            { bsonType: ["double", "int"] },
          se:               { bsonType: ["double", "int", "null"] },
          cv:               { bsonType: ["double", "int", "null"] },
          confint_lower:    { bsonType: ["double", "int", "null"] },
          confint_upper:    { bsonType: ["double", "int", "null"] },
          metadata:         { bsonType: ["object", "null"] },
          user:             { bsonType: "string" },
          user_info:        { bsonType: ["object", "null"] },
          published_at:     { bsonType: "string" },
          metasurvey_version: { bsonType: ["string", "null"] }
        }
      }
    }
  });
  print("[OK] indicators");
} catch (e) {
  if (e.codeName === "NamespaceExists") {
    print("[SKIP] indicators — already exists");
  } else {
    print("[ERROR] indicators: " + e.message);
  }
}

db.indicators.createIndex({ "id": 1 },            { unique: true, sparse: true });
db.indicators.createIndex({ "recipe_id": 1 });
db.indicators.createIndex({ "workflow_id": 1 });
db.indicators.createIndex({ "survey_type": 1 });
db.indicators.createIndex({ "published_at": -1 });
db.indicators.createIndex({ "survey_type": 1, "edition": 1 });
db.indicators.createIndex(
  { "name": "text", "description": "text" },
  { name: "indicators_text_search" }
);

// --- stars ---
try {
  db.createCollection("stars", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["user", "target_type", "target_id", "value", "created_at", "updated_at"],
        properties: {
          user:        { bsonType: "string" },
          target_type: { enum: ["recipe", "workflow"] },
          target_id:   { bsonType: "string" },
          value:       { bsonType: ["int", "double"], minimum: 1, maximum: 5 },
          created_at:  { bsonType: "string" },
          updated_at:  { bsonType: "string" }
        }
      }
    }
  });
  print("[OK] stars");
} catch (e) {
  if (e.codeName === "NamespaceExists") {
    print("[SKIP] stars — already exists");
  } else {
    print("[ERROR] stars: " + e.message);
  }
}

db.stars.createIndex(
  { "user": 1, "target_type": 1, "target_id": 1 },
  { unique: true, name: "stars_user_target" }
);
db.stars.createIndex(
  { "target_type": 1, "target_id": 1 },
  { name: "stars_target" }
);

// --- comments ---
try {
  db.createCollection("comments", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["id", "user", "user_name", "target_type", "target_id", "text", "created_at"],
        properties: {
          id:          { bsonType: "string" },
          user:        { bsonType: "string" },
          user_name:   { bsonType: "string" },
          target_type: { enum: ["recipe", "workflow"] },
          target_id:   { bsonType: "string" },
          text:        { bsonType: "string", minLength: 1, maxLength: 2000 },
          created_at:  { bsonType: "string" }
        }
      }
    }
  });
  print("[OK] comments");
} catch (e) {
  if (e.codeName === "NamespaceExists") {
    print("[SKIP] comments — already exists");
  } else {
    print("[ERROR] comments: " + e.message);
  }
}

db.comments.createIndex({ "id": 1 }, { unique: true });
db.comments.createIndex(
  { "target_type": 1, "target_id": 1, "created_at": 1 },
  { name: "comments_target_date" }
);

// --- backlinks index on recipes.depends_on_recipes ---
db.recipes.createIndex({ "depends_on_recipes": 1 });

print("[OK] All indexes created");

// ---------------------------------------------------------------------------
// 3. Summary
// ---------------------------------------------------------------------------
print("\n=== Summary ===");
["users", "recipes", "workflows", "anda_variables", "indicators", "stars", "comments"].forEach(function(c) {
  var count = db[c].countDocuments({});
  var idxCount = db[c].getIndexes().length;
  print("  " + c + ": " + count + " docs, " + idxCount + " indexes");
});
print("\nSetup complete. Next: seed data with seed_ech_recipes.R");
