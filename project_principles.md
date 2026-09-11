* Use Swift
* Prefer standard libraries to do heavy lifting and not reinvent the wheel, e.g. use Spritekit instead of inventing your own sprite engine, use SF Symbols if there's a good match for an icon, etc.
* Use modular architecture, e.g. don't do thousands of lines of logic in one big file: break up into logically separated files so each file is responsible for one area
* Take advantage of unit testing to enforce game logic and prevent regressions
* The model should focus on unit testing and must not use the simulator; leave black-box and functional testing to the user unless the user explicitly asks otherwise.
* Aim for a rock solid 60 FPS minimum performance level, even if it means less visual fidelity or other sacrifices
* Don't use any libraries/tools/functions that wouldn't work on an iPhone 13; that's our target minimum platform
* But within the phone version and performance requirements, aim for a beautiful presentation: lush, vibrant, clean, modern, slick
* Do not use emojis in the app unless specifically asked for
* Do not create sound effects or music unless user specifically asks for it
* Remind the user about standard mobile development practices (user is a backend developer who doesn't have a lot of mobile app development experience) where it's helpful. Prefer doing things in a modern, standard way unless the user explicitly overrides that after you ask the user during a choice point.
* Don't modify any of the project's .md files unless user asks for it
