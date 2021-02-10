FROM mcr.microsoft.com/powershell:latest

SHELL [ "pwsh", "-noprofile", "-noninteractive", "-executionpolicy", "bypass", "-command", "$ErrorActionPreference = 'Stop';", "$ProgressPreference = 'SilentlyContinue';" ]

RUN Install-PackageProvider PowerShellGet -Force -ForceBootstrap
RUN Install-Module PSDepend, posh-git -Force -AllowClobber -Repository psgallery

COPY ./.depend.psd1 /tmp/.depend.psd1
RUN Invoke-PSDepend /tmp/.depend.psd1 -Force; rm /tmp/.depend.psd1

CMD [ "pwsh" ]