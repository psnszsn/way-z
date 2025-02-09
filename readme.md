# Way-Z

Native Zig Wayland client library and widget toolkit

## Description

This project has a few different parts:

- Wayland client library (in `wayland/`): This can be used to crate a statically linked binary capable of displaying CPU rendered graphics.
- Widget toolkit (in `toolkit/`): This builds over the wayland client and povides a Data Oriented library for creating GUI apps
- Apps (in `apps/`): Demo apps built using the widget toolkit
    
## Getting Started

### Dependencies

* Zig 0.14.0-dev.3086+b3c63e5de

### Runnig examples

* `zig build run-hello`


## Inspired by

* [Serenity OS](https://github.com/SerenityOS/serenity)
* [Druid](https://github.com/linebender/druid)
