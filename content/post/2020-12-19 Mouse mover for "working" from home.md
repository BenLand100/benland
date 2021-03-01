---
title: Mouse mover program for "working" from home
date: '2020-12-19'
categories:
  - Programming
description: A simple Windows tray application that can move your mouse to keep you "active" while away from your machine
slug: mouse-mover-work-from-home
toc: false
---

I was commissioned to solve a critical problem during the Covid-19 pandemic: staying active on Slack / Microsoft Teams / etc while not actually at your computer.
Apparently some workplaces monitor your work-from-home habits based entirely on whether your status on these messaging applications is "Active."
This is decently effective, since you have to be moving your mouse and/or typing to remain active, which nominally ensures you are at your work computer.
However, you could be browsing Facebook looking at cat pictures instead, or other non-work activities, and if that flies, I think you should probably be allowed to go into the kitchen to make a tasty snack without the corporate panopticon realizing you're not "Active."

Fortunately this ~~invasive spying~~ monitoring is pretty easy to fool. 
You could opt for a low tech solution, like a widget to wiggle your mouse (or press a key on your keyboard) from time to time.
I decided it was probably best to write [a simple program](https://github.com/BenLand100/mouse_move) to do this without any input from the physical world.
This program is targeted for Microsoft Windows (sorry OSX users) but also runs fine in [Wine](https://www.winehq.org/) if you need to run it on Linux.
As I have been a Linux user for over a decade now, I wrote this to be built with [MinGW](http://www.mingw.org/) for Windows.

## Functionality 

When launched, a red mouse icon will appear in your tray. 
Left click the tray icon to start random motion, and left click it again to stop. 
A right click will close it, in case anyone tries to snoop. 
This program does not need to be installed, and can be run from a USB drive (which can immediately be removed after launch) if you are concerned about it being found.

Every 10 seconds the mouse will be moved to a random location, and NUMLOCK will be toggled.
This will keep you active on both Slack and Microsoft Teams, and will probably work for any similar status monitoring.
Feel free to tailor this to your own needs.

## The Code

The entire program is 125 lines (including empty lines!) and easily comprehensible.
This would be a good template for a tray-only application, if you need a starting point.

~~~C++
#ifndef UNICODE
#define UNICODE
#endif 

#include <windows.h>

#include <cstdio>
#include <iostream>

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
DWORD WINAPI MovementThread( LPVOID lpParam );

HWND hwnd;
HICON stopped_ico, running_ico;
NOTIFYICONDATA niData; 
bool running;

DWORD WINAPI MovementThread( LPVOID lpParam ) 
{
    int w = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    int h = GetSystemMetrics(SM_CYVIRTUALSCREEN);
    while (true) {
        while (running) {
            int x = rand()*w/RAND_MAX;
            int y = rand()*h/RAND_MAX;
            printf("%i %i\n",x,y);
            SetCursorPos(x,y);
            keybd_event(VK_NUMLOCK, 0x45, KEYEVENTF_EXTENDEDKEY, 0);
            keybd_event(VK_NUMLOCK, 0x45, KEYEVENTF_EXTENDEDKEY|KEYEVENTF_KEYUP, 0);
            Sleep(1000*10);
        }
        Sleep(1000);
    }
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE, LPSTR pCmdLine, int _nCmdShow)
{
    const wchar_t CLASS_NAME[]  = L"MouseMove Window Class";   
    WNDCLASS wc = { };
    wc.lpfnWndProc   = WindowProc;
    wc.hInstance     = hInstance;
    wc.lpszClassName = CLASS_NAME;
    RegisterClass(&wc);

    //dummy window (never shown)
    hwnd = CreateWindowEx(NULL, CLASS_NAME, L"MouseMove", WS_OVERLAPPED | WS_MINIMIZEBOX | WS_SYSMENU, CW_USEDEFAULT, CW_USEDEFAULT, 250, 80, NULL, NULL, hInstance, NULL);
    
    running = false;
    CreateThread(NULL, 0, MovementThread, NULL, 0, NULL);

    running_ico = (HICON)LoadIcon(hInstance,MAKEINTRESOURCE(1));
    stopped_ico = (HICON)LoadIcon(hInstance,MAKEINTRESOURCE(2));
    
    ZeroMemory(&niData,sizeof(NOTIFYICONDATA));
    niData.cbSize = sizeof(NOTIFYICONDATA);
    niData.uID = 42;
    niData.uFlags = NIF_ICON|NIF_MESSAGE|NIF_TIP;
    niData.hIcon = stopped_ico;
    niData.hWnd = hwnd;
    niData.uCallbackMessage = WM_APP;
    Shell_NotifyIcon(NIM_ADD,&niData);
    
    MSG msg = { };
    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    
    return 0;
}

void toggle() {
    running = !running;
    printf("toggle\n");
    if (running) {
        niData.hIcon = running_ico;
    } else { 
        niData.hIcon = stopped_ico;
    }
    Shell_NotifyIcon(NIM_MODIFY,&niData);
}

void quit() {
    Shell_NotifyIcon(NIM_DELETE,&niData);
    PostQuitMessage(0);
}

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    switch (uMsg)
    {
        case WM_APP:
            switch(lParam)
            {
                case WM_RBUTTONDOWN:
                    quit();
                    break;
                case WM_LBUTTONDOWN:
                    toggle();
                    break;
            }
            return 0;
            
        case WM_COMMAND:
            toggle();
            return 0;
            
        case WM_DESTROY:
            quit();
            return 0;

        case WM_PAINT:
            {
                PAINTSTRUCT ps;
                HDC hdc = BeginPaint(hwnd, &ps);
                FillRect(hdc, &ps.rcPaint, (HBRUSH) (COLOR_WINDOW+1));
                EndPaint(hwnd, &ps);
            }
            return 0;
            
    }

    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}
~~~

An icon resource file is necessary to get preetty tray and executable icons:
~~~
0   ICON    "mouse.ico"
1   ICON    "running.ico"
2   ICON    "stopped.ico"
~~~

The build script is equally simple:
~~~sh
x86_64-w64-mingw32-windres icons.rc -O coff -o icons.res
x86_64-w64-mingw32-g++ -fno-exceptions -fno-rtti -s -O3 -static -mwindows main.cpp icons.res -lstdc++ -o mouse_move    
~~~

## Obtaining the program

I strongly suggest always building software yourself, or obtaining from a reputable source.
(I run [Gentoo Linux](https://www.gentoo.org/) after all, and any other stance would be counter to my base drives.)
If, however, you like to live dangerously, or refuse to learn how to build programs, there is a prebuilt version available [on my github](https://github.com/BenLand100/mouse_move/releases/download/v1.0/mouse_move.exe).
