# Description of suggested change

## Current state

Today this module uses a scaffolded module structure and build process from "Sampler" which originally was developed for Powershell DSC resources.

The reason for this change is that this build process feels -very- cumbersome with a lot of functionallity that is normally not used and it is very complex. I would like a more streamlined build/release/CI/CD process.

I want you to inspect the full release pipeline in this repo and replace it with a more modern, git/github compatible build process with modern tools. I'll try to explain how it currently works today.

### Build script

The build script build.ps1 uses a quite complex method of first running as a bootstrap and then invokes itself to run Invoke-ModuleBuild. It loads a yaml reading module and parses a build.yaml file with some settings. It uses PSDepend for module dependencies. GitVersion for versioning. Then it uses the Sampler module and its plugin to perform different build stages. These build stages seem to merge variables from environment variables, build.yaml file and parameters sent through the build-script. It is all very complex and hard to get a overview of what is actually happening.

The build.yaml script contains the order of what steps need to run. I've build some custom samples tasks.

The Sampler tasks handle things like
- build powershell module
- create changelog
- release tagging
- PSDeplout
- generate help
- running pester
- codecoverage
- github integration etc.

I cant really tell what is doing what, which is the main problem.

## What i want

I want the new build process to basically be a drop in replacement but Im open to changing way-of-working related changes when that makes sense.

I really like the self-containment of the build-process, it should be repeatable and resolve any dependencies by itself. Currently dependency powershell modules are stored in "output/RequiredModules". If any are missing, they are downloaded. The build processes priorities module loading from this directory so the installed modules on the development machine dont matter.

I like and is very used to the folder structure of output, source and tests, with build related files in the root.

You recently helped me in another new project (unrelated, not even powershell) that used the "Please release" process that works good with git and github. I think i like that.

It is important that the steps to create the powershell module is all included when it makes sense, for instance how the powershell module is packaged etc.

But ultimatly i want a more simple build process that I can understand and troubleshoot. I feel that one of the current issues is that the current build process is "generic" in a way where it is supposed to handle so many different scenarios that my scenario does not have any intreset of.

Ultimatly i want you to remove all stuff that we no longer need.

This work also includes working through the github actions so that it fits in nicley with the new build process.

Working with development should be easy and i want a help document that shows me how to make changes that does not result in a release, how to release, pin versions etc.

Today what i do when i want to release a new version is that i tag it, like "git tag v.X.X.X"; "git push origin v.X.X.X", i dont say that it must work like that, i just want you to understand the workflow today.

I've created a new branch for this work so you can start working and I'll inspect it before merging.
