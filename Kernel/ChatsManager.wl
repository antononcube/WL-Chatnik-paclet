(**************************************************************)
(* Package definition                                         *)
(**************************************************************)

BeginPackage["AntonAntonov`Chatnik`ChatsManager`"];

Begin["`Private`"];

Needs["AntonAntonov`Chatnik`"];
Needs["Wolfram`CommandLineParser`"];

Clear[Proclaimer];
Proclaimer[x_] := Echo[x, "Chatnik:"];

(***************************************************************)
(* Parse shortcut model spec                                   *)
(***************************************************************)

Clear[GetProviderAndModel];
GetProviderAndModel[spec_String] := 
  Module[{provider, model}, 
   If[StringContainsQ[spec, "::"], 
    {provider, model} = StringSplit[spec, "::"];
    provider =
      Switch[ToLowerCase[provider],
        "chatgpt", "OpenAI",
        "google", "Gemini",
        "ollama", "Ollama",
        "chatollama", "Ollama",
        _, provider
        ];
    <|"Service" -> provider, "Name" -> model|>,
    (*ELSE*)
    <|"Service" -> "OpenAI", "Name" -> spec|>
    ]
   ];

(***************************************************************)
(* LLM configuration by CLI-parsed arguments.                  *)
(***************************************************************)

Clear[LLMConfigurationByArgs];
LLMConfigurationByArgs[args_Association] :=
  Module[{aMapToKnown, knownParamNames, confArgs, unknown, spec, confArgs2},
   
    aMapToKnown = <|
      "i" -> "chat-id",
      "id" -> "chat-id",
      "max-tokens" -> "MaxTokens",
      "model" -> "Model",
      "prompt-delimiter" -> "PromptDelimiters",
      "prompt" -> "Prompts",
      "prompts" -> "Prompts",
      "reasoning" -> "Reasoning",
      "stop-tokens" -> "StopTokens",
      "temperature" -> "Temperature",
      "tools" -> "Tools",
      "top-probabilities" -> "TopProbabilities",
      "TotalProbabilityCutoff" -> "total-probability-cutoff"
    |>;

   knownParamNames = Values[aMapToKnown];

   confArgs = KeyTake[KeyMap[# /. aMapToKnown&, args], knownParamNames];
   If[Length[args] > Length[confArgs], 
     unknown = Keys@KeySelect[args, (! MemberQ[knownParamNames, #]) && (!MemberQ[{"chat-id", "prompt"}, #]) &];
    
     If[Length[unknown] > 0,
       Proclaimer["Unknown LLM configuration option" <> If[Length[unknown] > 1, "s", ""] <> ": '" <> StringRiffle[unknown, ", "] <> "'."]
     ]
   ];
   
   If[! KeyExistsQ[confArgs, "Model"] && Environment["CHATNIK_DEFAULT_MODEL"] =!= $Failed, 
    confArgs["Model"] = Environment["CHATNIK_DEFAULT_MODEL"]
   ];
   
   If[KeyExistsQ[confArgs, "Model"],
     spec = GetProviderAndModel[confArgs["Model"]];
     confArgs["Service"] = spec["Service"];
     confArgs["Name"] = spec["Name"];
  ];
   
   confArgs2 = KeyDrop[confArgs, {"Service", "Name", "Model"}];
   LLMConfiguration[Join[<|"Model" -> {confArgs["Service"], confArgs["Name"]}|>, confArgs2]]
];

(***************************************************************)
(* CLI argument parsing specs                                  *)
(***************************************************************)

posArgSpecs = {"input" -> StringSpec["Chat input text."]};

optArgSpecs = {
   {"chat-id", "NONE"} -> StringSpec["Chat ID."],
   {"model", "gpt-5-mini"} -> StringSpec["Model spec, e.g. 'ollama::gpt-oss:20b' or 'gpt-5.3-chat-latest'."],
   {"max-tokens", "-1"} -> NumericSpec["Integer", "Max number of tokents.", "Interval" -> {-1, Infinity}, "AllowInfinity" -> True],
   {"prompt", ""} -> StringSpec["Prompt used for chat object creation."],
   {"temperature", "-1"} -> NumericSpec["Real", "Temperature used for LLM generation.", "Interval" -> {-1, 3}],
   {"reasoning", "none"} -> StringSpec["Reasoning effort."]
};

helpHeader = "Chat with persistent LLM-chat objects.";

spec = {posArgSpecs, optArgSpecs, helpHeader};

(***************************************************************)
(* Chatnik evaluate                                            *)
(***************************************************************)
Clear[ChatnikEvaluate];

Options[ChatnikEvaluate] = Join[Options[ChatEvaluate], {"Location" -> "Local"}];

ChatnikEvaluate[args:{_String...}, opts: OptionsPattern[]] := 
  Module[{res},
    res = ParseCommandLine[spec, args];
    ChatnikEvaluate[
      res[[1]]["input"], 
      Select[res[[2]], NumericQ[#] && # >= 0 || StringQ[#] && !MemberQ[{"none", "automatic", "auto"}, ToLowerCase[#]]&], 
      opts
    ]
  ];

ChatnikEvaluate[input_?StringQ, aArgs_?AssociationQ, opts: OptionsPattern[]] :=
  Module[{location, aChats, chatID, prompt, conf, chatObj, sep, resObj, ans},

   location = OptionValue[ChatnikEvaluate, "Location"];
   
   (*Get persistent chats*)
   aChats = PersistentSymbol["ChatnikChats", location];
   If[! AssociationQ[aChats], aChats = <||>];
   
   (*Get chat ID*)
   chatID = Lookup[aArgs, "chat-id", Lookup[aArgs, "id", Lookup[aArgs, "i", "NONE"]]];
   
   (*Get prompt*)
   prompt = Lookup[aArgs, "prompt", Nothing];
   
   (*Warn if an existing chat-
   id is used and are also given a prompt and configuration spec*)
   If[(StringQ[prompt] || Length[KeyDrop[aArgs, {"chat-id", "id", "i"}]] > 0) && KeyExistsQ[aChats, chatID],
     Proclaimer[
       StringTemplate["No new chat object is created.\nUsing chat object with id: ⎡`1`⎦, and number of messages: `2`"][chatID, Length@aChats[chatID]["Messages:"]]
     ]
   ];
   
   (*Create an LLM configuration*)
   conf = LLMConfigurationByArgs[KeyDrop[aArgs, {"chat-id", "id", "i"}]];
   
   (*Get chat object*)
   chatObj = Lookup[aChats, chatID, ChatObject[prompt, LLMEvaluator -> conf]];
   
   (*We can get a delimiter from the configuration.
   But for prompt expansions it is most like better to use new line.*)
   sep = "\n";
   
   (*Evaluate message*)
   resObj = Enclose[Confirm[ChatEvaluate[chatObj, input, FilterRules[{opts}, Options[ChatEvaluate]] ]]];
   
   (*Register*)
   aChats[chatID] = resObj;
   PersistentSymbol["ChatnikChats", location] = aChats;
   
   (*Result*)
   ans = Last@resObj["Messages"];
   If[KeyExistsQ[ans, "Content"],
     ans = StringRiffle[Map[First@KeyDrop[#, "Type"] &, Select[ans["Content"], #["Type"] == "Text" &]], sep]
   ];
   ans
];

ChatnikEvaluate[___]:=(Proclaimer["The first argument is expected to be a string, the second argument is expected to be an association."]; $Failed);

End[]; (*`Private`*)

EndPackage[]