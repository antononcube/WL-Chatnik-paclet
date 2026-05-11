(*BeginTestSection["Prompt-DSL-parsing-unit-tests.wlt"];*)

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
  aParsers = AntonAntonov`Chatnik`PromptExpander`Private`aParsers,
  _Association,
  SameTest -> MatchQ,
  TestID -> "Test-Prompt-parsing-aParsers-shape-1"
];

(* Test 3 *)
VerificationTest[
  Sort @ Keys @ aParsers,
  {"Func", "FuncCell", "FuncPrior", "Modifier", "Persona"},
  SameTest -> Equal,
  TestID -> "Test-Prompt-parsing-aParsers-shape-2"
];

(* Test 4 *)
VerificationTest[
  spec1 = "#HaikuStyled #Translated";
  StringCases[spec1, aParsers["Modifier"]],
  {<|"name" -> "HaikuStyled", "params" -> ""|>, <|"name" -> "Translated", "params" -> ""|>},
  TestID -> "Test-Prompt-parsing-modifier-1"
];

(* Test 5 *)
VerificationTest[
  spec2 = "#HaikuStyled #Translated|German";
  StringCases[spec2, aParsers["Modifier"]],
  {<|"name" -> "HaikuStyled", "params" -> ""|>, <|"name" -> "Translated", "params" -> "German"|>},
  TestID -> "Test-Prompt-parsing-modifier-2"
];

(* Test 6 *)
VerificationTest[
  spec3 = {"!Translated|Russian", "&Translated|'High German'"};
  StringCases[spec3, aParsers["Func"]],
  {{<|"name" -> "Translated", "params" -> "Russian"|>}, {<|"name" -> "Translated", "params" -> "'High German'"|>}},
  TestID -> "Test-Prompt-parsing-function-1"
];

(* Test 7 *)
VerificationTest[
  spec4 = {"!Translated|'High German'> what is good?", "!Translated|Russian> what is good?"};
  StringCases[spec4, aParsers["FuncCell"]],
  {
    {<|"name" -> "Translated", "params" -> "'High German'", "cellArg" -> "what is good?"|>}, 
    {<|"name" -> "Translated", "params" -> "Russian>", "cellArg" -> "what is good?"|>}
  },
  TestID -> "Test-Prompt-parsing-function-cell-1"
];

(* Test 8 *)
VerificationTest[
  spec5 = "@CodeWriterX|Python reverse a string";
  StringCases[spec5, aParsers["Persona"]],
  {<|"name" -> "CodeWriterX", "params" -> "Python"|>},
  TestID -> "Test-Prompt-parsing-persona-1"
];

(* Test 9 *)
VerificationTest[
  spec6 = "@Yoda";
  StringCases[spec6, aParsers["Persona"]],
  {<|"name" -> "Yoda", "params" -> ""|>},
  TestID -> "Test-Prompt-parsing-persona-2"
];

(* Test 9 *)
VerificationTest[
  spec6 = "@Yoda hi! Who are you?";
  StringCases[spec6, aParsers["Persona"]],
  {<|"name" -> "Yoda", "params" -> ""|>},
  TestID -> "Test-Prompt-parsing-persona-3"
];

(*EndTestSection[]*)
