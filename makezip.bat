@echo off
if not exist build (
mkdir build
)
if not exist build\SurvivalMod.7z (
7z a build\SurvivalMod.7z ..\..\Content\System\SurvivalMod.u Readme.md
)
