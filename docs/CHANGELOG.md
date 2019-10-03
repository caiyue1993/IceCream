# Change Log

## [1.12.0 - Background Worker](https://github.com/caiyue1993/IceCream/releases/tag/1.12.0)

#### Add

* Implement background synchronization [#155](https://github.com/caiyue1993/IceCream/pull/155)

#### Fix 

* Fix primaryKey wrongly convertion issue [#165](https://github.com/caiyue1993/IceCream/pull/165)

## [1.11.0 - You Want This Completion Handler](https://github.com/caiyue1993/IceCream/releases/tag/1.11.0)

#### Add

* Add a completionHandler in the pull method [#141](https://github.com/caiyue1993/IceCream/pull/141)

## [1.10.1](https://github.com/caiyue1993/IceCream/releases/tag/1.10.1)

#### Fix

* Fix Carthage build failing issue on macOS, watchOS and tvOS

## [1.10.0 - Swift 5](https://github.com/caiyue1993/IceCream/releases/tag/1.10.0)

#### Add

* Now IceCream builds against Swift 5.0 and Xcode 10.2.

## [1.9.0 - Make It Public](https://github.com/caiyue1993/IceCream/releases/tag/1.9.0)

#### Add

* Add support for public database [#124](https://github.com/caiyue1993/IceCream/pull/124)

## [1.8.0 - Customization](https://github.com/caiyue1993/IceCream/releases/tag/1.8.0)

#### Add

* Add a option to let developer choose whether to overwrite existing CreamAsset file(the default choice is `true`) [#103](https://github.com/caiyue1993/IceCream/pull/103)
* Add support for custom CKContainers [#104](https://github.com/caiyue1993/IceCream/pull/104)
* Add support for custom Realm [#108](https://github.com/caiyue1993/IceCream/pull/108)

#### Fix

* Fix the conversion issue of recordID to Int type primaryKey [#111](https://github.com/caiyue1993/IceCream/pull/111)

## [1.7.2 - Realm List of Basic Types](https://github.com/caiyue1993/IceCream/releases/tag/1.7.2)

#### Add

* Add support for Lists of basic types [#98](https://github.com/caiyue1993/IceCream/pull/98)

#### Fix 

* Fix a crash when new no-optional property added [#92](https://github.com/caiyue1993/IceCream/pull/92)
* Avoid force unwrapping `storedData` [#101](https://github.com/caiyue1993/IceCream/pull/101)

## [1.7.1 - Optimizations](https://github.com/caiyue1993/IceCream/releases/tag/1.7.1)

#### Add

* Add `pushAll` method. 
* change method name `sync` to `pull`. 

#### Fix 

* Fetch changes on the non-main thread.
* Move registerLocalDatabase to completion block of createCustomZones.
* Fix `isCustomZoneCreated` setter logic.
* More Swift 4.2 and optimize code style.

-----
## 1.7.0 - Swift 4.2

#### Add

* Xcode 10 / Swift 4.2 support

-----
## [1.6.0 - Get me on every Apple platform](https://github.com/caiyue1993/IceCream/releases/tag/1.6.0)

#### Add

* Adding support for macOS, tvOS and watchOS. [#79](https://github.com/caiyue1993/IceCream/pull/79),[#85](https://github.com/caiyue1993/IceCream/pull/85)

-----
## [1.5.0 - Dog has an Owner](https://github.com/caiyue1993/IceCream/releases/tag/1.5.0)

#### Add

* Many-to-one relationship support. [#74](https://github.com/caiyue1993/IceCream/pull/74)

#### Fix

* Carthage nested dependency issue. [#71](https://github.com/caiyue1993/IceCream/pull/71)

-----
## [1.4.2](https://github.com/caiyue1993/IceCream/releases/tag/1.4.2)

#### Add

* Expose file path in CreamAsset. [#66](https://github.com/caiyue1993/IceCream/pull/66) 

-----
## [1.4.1](https://github.com/caiyue1993/IceCream/releases/tag/1.4.1)

#### Fix

* Fix the folder file issue. [#60](https://github.com/caiyue1993/IceCream/pull/60) 

-----
## [1.4.0 - Dogs and Cats](https://github.com/caiyue1993/IceCream/releases/tag/1.4.0)

#### Add

* Multiple object models support. [#55](https://github.com/caiyue1993/IceCream/pull/55) 

-----
## [1.3.3](https://github.com/caiyue1993/IceCream/releases/tag/1.3.3)

#### Fix 

* Change the deployment target via Carthage. [#50](https://github.com/caiyue1993/IceCream/pull/50) 

-----
## [1.3.2 - Faster](https://github.com/caiyue1993/IceCream/releases/tag/1.3.2)

#### Fix 

* Static Framework Support. [#47](https://github.com/caiyue1993/IceCream/pull/47) 

-----
## [1.3.1 - Lean Code](https://github.com/caiyue1993/IceCream/releases/tag/1.3.1)

#### Fix 

* Use where clause to refactor code. [#46](https://github.com/caiyue1993/IceCream/pull/46) 

-----
## [1.3.0 - Decentralized is the Future](https://github.com/caiyue1993/IceCream/releases/tag/1.3.0)

#### Add

* Support Carthage. [#34](https://github.com/caiyue1993/IceCream/pull/34)

#### Fix 

* CreamAsset behaves better. [#32](https://github.com/caiyue1993/IceCream/pull/32) 

-----
## [1.2.1 - Make yourself at home](https://github.com/caiyue1993/IceCream/releases/tag/1.2.1)

#### Add

* Log or not log. It's up to you. [#23](https://github.com/caiyue1993/IceCream/issues/23)

-----
## [1.2.0 - Colorful World](https://github.com/caiyue1993/IceCream/releases/tag/1.2.0)

#### Add

* CKAsset Support. [#24](https://github.com/caiyue1993/IceCream/pull/24)

#### Fix

* Make Error Handler perfect. [26](https://github.com/caiyue1993/IceCream/pull/26) 

-----

## [1.1.0 - Error Handler Matters](https://github.com/caiyue1993/IceCream/releases/tag/1.1.0)

#### Add

* A powerful Error Handler. [#15](https://github.com/caiyue1993/IceCream/pull/15).

-----

## [1.0.0 - Dressed Up!](https://github.com/caiyue1993/IceCream/releases/tag/1.0.0)

#### Fix

* Subscription bug. [#12](https://github.com/caiyue1993/IceCream/pull/12).

* Bye bye, magic strings. [#11](https://github.com/caiyue1993/IceCream/pull/11)

---

## [0.2.0 - One line of code, all settled](https://github.com/caiyue1993/IceCream/releases/tag/0.2.0)

#### Fix

* Using protocol extensions to refactor code. Now users just need to add one line of code to use IceCream. [#2](https://github.com/caiyue1993/IceCream/issues/2)

---

## [0.1.1](https://github.com/caiyue1993/IceCream/releases/tag/0.1.1)

#### Add

* Swift version assigned.

---

## [0.1.0 - The world gonna be mine!](https://github.com/caiyue1993/IceCream/releases/tag/0.1.0)

IceCream was born!