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
        "openai", "OpenAI",
        "google", "Gemini",
        "gemini", "Gemini",
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
     unknown = Keys@KeySelect[args, (! MemberQ[knownParamNames, #]) && (!MemberQ[{"chat-id", "prompt", "model", "echo"}, #]) &];
    
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
     confArgs["Name"] = spec["Name"],
     (*ELSE*)
     confArgs["Service"] = "OpenAI";
     confArgs["Name"] = "gpt-4.1-mini"
   ];
   
   confArgs2 = KeyDrop[confArgs, {"Service", "Name", "Model"}];
   LLMConfiguration[Join[<|"Model" -> {confArgs["Service"], confArgs["Name"]}|>, confArgs2]]
];

(***************************************************************)
(* CLI argument parsing specs                                  *)
(***************************************************************)

posArgSpecs = {"input" -> StringSpec["Chat input text."]};

optArgSpecs = {
   {"chat-id", ""} -> StringSpec["Chat ID."],
   {"id", ""} -> StringSpec["Chat ID. (Ignored if --chat-id is present.)"],
   {"i", "NONE"} -> StringSpec["Chat ID. (Ignored if --chat-id or --id are present.)"],
   {"model", ""} -> StringSpec["Model spec, e.g. 'ollama::gpt-oss:20b' or 'gpt-5.3-chat-latest'."],
   {"max-tokens", "-1"} -> NumericSpec["Integer", "Max number of tokents.", "Interval" -> {-1, Infinity}, "AllowInfinity" -> True],
   {"prompt", ""} -> StringSpec["Prompt used for chat object creation."],
   {"temperature", "-1"} -> NumericSpec["Real", "Temperature used for LLM generation.", "Interval" -> {-1, 3}],
   {"reasoning", ""} -> StringSpec["Reasoning effort."],
   {"echo", "false"} -> BooleanSpec["Whether to echo the intermediate results or not."]
};

helpHeader = "Chat with persistent LLM-chat objects.";

spec = {posArgSpecs, optArgSpecs, helpHeader};

(***************************************************************)
(* Chatnik evaluate                                            *)
(***************************************************************)
Clear[ChatnikEvaluate];

Options[ChatnikEvaluate] = { "Location" -> "Local", "Clone" -> False, "Echo" -> False, "ProgressReporting" -> False};

ChatnikEvaluate[args:{_String...}, opts: OptionsPattern[]] := 
  Module[{res, args2, echoQ},
    
    res = ParseCommandLine[spec, args];
    args2 = Select[res[[2]], BooleanQ[#] || NumericQ[#] && # >= 0 || StringQ[#] && !MemberQ[{"none", "automatic", "auto", ""}, StringTrim@ToLowerCase@#]&];

    echoQ = args2["echo"];

    If[echoQ, Proclaimer["ParseCommandLine result : " <> ToString[args2] ]];

    ChatnikEvaluate[res[[1]]["input"], args2, "Echo" -> echoQ, opts]
  ];

ChatnikEvaluate[input_?StringQ, aArgs_?AssociationQ, opts: OptionsPattern[]] :=
  Module[{location, echoQ, cloneQ, progressQ, aChats, chatID, prompt, conf, confNew, chatObj, sep, resObj, ans},

   location = OptionValue[ChatnikEvaluate, "Location"];
   cloneQ = TrueQ[OptionValue[ChatnikEvaluate, "Clone"]];
   echoQ = TrueQ[OptionValue[ChatnikEvaluate, "Echo"]];
   progressQ = TrueQ[OptionValue[ChatnikEvaluate, "ProgressReporting"]];
    
   (*Get persistent chats*)
   aChats = PersistentSymbol["ChatnikChats", location];
   If[! AssociationQ[aChats], aChats = <||>];
   
   If[echoQ, Proclaimer["Persistent chat IDs : " <> ToString[Keys[aChats]]]];

   (*Get chat ID*)
   chatID = Lookup[aArgs, "chat-id", Lookup[aArgs, "id", Lookup[aArgs, "i", "NONE"]]];
   
   If[echoQ, Proclaimer["chat-id : " <> ToString[FullForm[chatID]] ]];

   (*Get prompt*)
   prompt = Lookup[aArgs, "prompt", Nothing];
   
   (*Warn if an existing chat-
   id is used and are also given a prompt and configuration spec*)
   If[(StringQ[prompt] || Length[KeyDrop[aArgs, {"chat-id", "id", "i", "echo"}]] > 0) && KeyExistsQ[aChats, chatID],
     Proclaimer[
       StringTemplate["No new chat object is created.\nUsing chat object with id: ⎡`1`⎦, and number of messages: `2`"][chatID, Length@aChats[chatID]["Messages:"]]
     ]
   ];
   
   (*Create an LLM configuration*)
   conf = LLMConfigurationByArgs[KeyDrop[aArgs, {"chat-id", "id", "i"}]];
   
   (*Get chat object*)
   If[ KeyExistsQ[aChats, chatID],
     chatObj = aChats[chatID];
     If[cloneQ,
       conf = chatObj["LLMEvaluator"];
       confNew = LLMConfiguration[conf, "Model" -> KeyTake[conf["Model"], {"Service", "Name"}]];
       chatObj = ChatObject[chatObj["Messages"], LLMEvaluator -> confNew]
     ],
     (*ELSE*)
     chatObj = ChatObject[prompt, LLMEvaluator -> conf]
    ];

   If[echoQ, Proclaimer["Chat object \"ChatID\" : " <> ToString[chatObj["ChatID"]]]];

   If[echoQ, Proclaimer["LLM-evaluator : " <> ToString[InputForm[chatObj["LLMEvaluator"]]]]];

   (*We can get a delimiter from the configuration.
   But for prompt expansions it is most like better to use new line.*)
   sep = "\n";
   
   (*Evaluate message*)
   resObj = Enclose[ConfirmBy[ChatEvaluate[chatObj, input, ProgressReporting -> progressQ], TrueQ[Head[#] === ChatObject]&, "ChatEvaluate"]];
   
   If[TrueQ[Head[resObj] === Failure],
    Proclaimer["Cannot evaluate the chat object with the given input. Message and chat object are not registered."];
    Return[$Failed]
   ];

   (*Register*)
   aChats[chatID] = resObj;
   PersistentSymbol["ChatnikChats", location] = aChats;
   
   (*Result*)
   ans = Last@resObj["Messages"];

   If[echoQ, Proclaimer["LLM-answer : " <> ToString[ans]]];
 
   If[AssociationQ[ans] && KeyExistsQ[ans, "Content"],
     ans = StringRiffle[Map[First@KeyDrop[#, "Type"] &, Select[ans["Content"], #["Type"] == "Text" &]], sep]
   ];
   ans
];

ChatnikEvaluate[___]:=(Proclaimer["The first argument is expected to be a string, the second argument is expected to be an association or a list of strings."]; $Failed);


(***************************************************************)
(* Clear messages                                              *)
(***************************************************************)

ChatnikClearMessages[chatObj_ChatObject] := ChatnikClearMessages[chatObj, All];

ChatnikClearMessages[chatObj_ChatObject, All] := 
    ChatnikClearMessages[chatObj, {1, Length @ chatObj["Messages"]}];

ChatnikClearMessages[chatObj_ChatObject, {min_, max_}] := 
    Module[{conf},
      conf = chatObj["LLMEvaluator"];
      conf = LLMConfiguration[conf, "Model" -> KeyTake[conf["Model"], {"Service", "Name"}]];
      ChatObject[Drop[chatObj["Messages"], {min, max}], LLMEvaluator -> conf]
    ];

End[]; (*`Private`*)

EndPackage[]