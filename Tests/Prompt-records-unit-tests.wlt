(*BeginTestSection["Prompt-records-unit-tests.wlt"];*)

pObj = PacletObject["AntonAntonov/Chatnik"];

(* Test 1 *)
VerificationTest[
  Quiet[Check[Needs["AntonAntonov`Chatnik`"], $Failed]],
  Null,
  SameTest -> MatchQ,
  TestID -> "Load-Chatnik"
];

(* Test 2 *)
VerificationTest[
  fileName = FileNameJoin[{pObj["Location"], "Resources", "Prompt-repository-records.json"}];
  FileExistsQ[fileName],
  True,
  TestID -> "Test-Prompt-records-file-found"
];

(* Test 3 *)
VerificationTest[
  Import[fileName, "RawJSON"],
  {_Association...},
  SameTest -> MatchQ,
  TestID -> "Import-1"
];

(*EndTestSection[]*)
