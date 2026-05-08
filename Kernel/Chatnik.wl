(* ::Package:: *)

(* ::Section:: *)
(*Package Header*)


BeginPackage["AntonAntonov`Chatnik`"];

ScrapePromptRecords::usage = "Scrapes LLM prompts info from a given URL. (Default URL is that of Wolfram Prompt Repository.)";

ChatnikEvaluate::usage = "ChatnikEvaluate[input_String, args_Association, location_] \
evaluates a message input using chat-ID and LLM-configuration options \
using persistent chat-objects association at specified location. (\"Local\" by default.)";

Begin["`Private`"];

Needs["AntonAntonov`Chatnik`Scraper`"];
Needs["AntonAntonov`Chatnik`ChatsManager`"];


End[];
EndPackage[];