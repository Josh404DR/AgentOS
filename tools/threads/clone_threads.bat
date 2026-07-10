@echo off
cd /d E:\AgentOS
echo Cloning Threads-Scraper...
git clone https://github.com/Zeeshanahmad4/Threads-Scraper.git
echo.
echo Installing requirements...
cd Threads-Scraper
pip install -r requirements.txt
echo.
echo Done! Press any key to close.
pause
