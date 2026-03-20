#!/usr/bin/env pwsh
# Run this once to initialize the repo and push to GitHub
# Usage: .\setup_github.ps1 -GitHubUsername your_username -RepoName comfyui-3d-docker

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubUsername,
    
    [Parameter(Mandatory=$false)]
    [string]$RepoName = "comfyui-3d-docker"
)

Write-Host "Setting up GitHub repo: $GitHubUsername/$RepoName" -ForegroundColor Cyan

# Initialize git
git init
git add .
git commit -m "Initial commit: ComfyUI 3D Docker with Hunyuan3D + Direct3D-S2"

# Create repo on GitHub (requires gh CLI - https://cli.github.com)
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "Creating GitHub repo via gh CLI..." -ForegroundColor Green
    gh repo create $RepoName --public --description "ComfyUI Docker image with Hunyuan3D and Direct3D-S2 support"
    git remote add origin "https://github.com/$GitHubUsername/$RepoName.git"
} else {
    Write-Host "gh CLI not found. Please:" -ForegroundColor Yellow
    Write-Host "  1. Create repo manually at https://github.com/new" -ForegroundColor Yellow
    Write-Host "  2. Then run:" -ForegroundColor Yellow
    Write-Host "     git remote add origin https://github.com/$GitHubUsername/$RepoName.git" -ForegroundColor White
}

git branch -M main
git push -u origin main

Write-Host ""
Write-Host "Done! Repo available at: https://github.com/$GitHubUsername/$RepoName" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Edit docker-compose.yml - set your models path" -ForegroundColor White
Write-Host "  2. Run: docker compose build" -ForegroundColor White
Write-Host "  3. Run: docker compose up" -ForegroundColor White
Write-Host "  4. Open: http://localhost:8188" -ForegroundColor White
