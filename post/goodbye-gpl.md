# 是时候和GPL说再见了【Martin Kleppmann】

由Martin Kleppmann于2021年4月14日发表。

> Martin Kleppmann是《设计数据密集型应用》（a.k.a DDIA）的作者，译者冯若航为该书中文译者。

本文的导火索是Richard Stallman[恢复原职](https://www.fsf.org/news/statement-of-fsf-board-on-election-of-richard-stallman)，对于[自由软件基金会](https://www.fsf.org/)（FSF）的董事会而言，这是一位[充满争议的人物](https://rms-open-letter.github.io/)。我对此感到震惊，并与其他人一起呼吁将他撤职。这次事件让我重新评估了自由软件基金会在计算机领域的地位 —— 它是GNU项目（[宽泛地说](https://www.gnu.org/gnu/incorrect-quotation.en.html)它属于Linux发行版的一部分）和以[GNU通用公共许可证](https://en.wikipedia.org/wiki/GNU_General_Public_License)（GPL）为中心的软件许可证系列的管理者。这些努力不幸被Stallman的行为所玷污。**然而这并不是我今天真正想谈的内容**。

在本文中，我认为**我们应该远离GPL和相关的许可证**（LGPL、AGPL），原因与Stallman无关，只是因为，我认为它们未能实现其目的，而且它们造成的麻烦比它们产生的价值要更大。

首先简单介绍一下背景：GPL系列许可证的定义性特征是 [copyleft](https://en.wikipedia.org/wiki/Copyleft) 的概念，它指出，如果你用了一些GPL许可的代码并对其进行修改或构建，你也必须在同一许可证下免费提供你的修改/扩展（被称为"[衍生作品](https://en.wikipedia.org/wiki/Derivative_work)"）（大致意思）。这样一来，GPL的源代码就不能被纳入闭源软件中。乍看之下，这似乎是个好主意。那么问题在哪里？

## 敌人变了

在上世纪80年代和90年代，当GPL被创造出来时，自由软件运动的敌人是微软和其他销售闭源（"专有"）软件的公司。GPL打算破坏这种商业模式，主要出于两个原因：

1. 闭源软件不容易被用户所修改；你可以用，也可以不用，但你不能根据自己的需求对它进行修改定制。为了抵制这种情况，GPL设计的宗旨即是，迫使公司发布其软件的源代码，这样软件的用户就可以研究、修改、编译和使用他们自己的修改定制版本，从而获得按需定制自己计算设备的自由。
2. 此外，GPL的动机也包括对公平的渴望：如果你在业余时间写了一些软件并免费发布，但是别人用它获利，又不向社区回馈任何东西，你肯定也不希望这样的事情发生。强制衍生作品开源，至少可以确保一些兜底的"回报"。

这些原因在1990年有意义，但我认为，世界已经变了，闭源软件已经不是主要问题所在。**在2020年，计算自由的敌人是云计算软件**（又称：软件即服务/SaaS，又称网络应用/Web Apps）—— 即主要在供应商的服务器上运行的软件，而你的所有数据也存储在这些服务器上。典型的例子包括：Google Docs、Trello、Slack、Figma、Notion和其他许多软件。

这些“云软件”也许有一个客户端组件（手机App，网页App，跑在你浏览器中的JavaScript），但它们只能与供应商的服务端共同工作。而云软件存在很多问题：

- 如果提供云软件的公司倒闭，或决定[停产](https://killedbygoogle.com/)，软件就没法工作了，而你用这些软件创造的文档与数据就被锁死了。对于初创公司编写的软件来说，这是一个很常见的问题：这些公司可能会被[大公司收购](https://ourincrediblejourney.tumblr.com/)，而大公司没有兴趣继续维护这些初创公司的产品。
- 谷歌和其他云服务可能在没有任何警告和[追索手段](https://www.paullimitless.com/google-account-suspended-no-reason-given/)的情况下，[突然暂停你的账户](https://twitter.com/Demilogic/status/1358661840402845696)。例如，您可能在完全无辜的情况下，被自动化系统判定为违反服务条款：其他人可能入侵了你的账户，并在你不知情的情况下使用它来发送恶意软件或钓鱼邮件，触发违背服务条款。因而，你可能会突然发现自己用Google Docs或其它App创建的文档全部都被永久锁死，无法访问了。
- 而那些运行在你自己的电脑上的软件，即使软件供应商破产了，它也可以继续运行，直到永远。（如果软件不再与你的操作系统兼容，你也可以在虚拟机和模拟器中运行它，当然前提是它不需要联络服务器来检查许可证）。例如，互联网档案馆有一个[超过10万个历史软件](https://archive.org/details/softwarelibrary)的软件集锦，你可以在浏览器中的模拟器里运行！相比之下，如果云软件被关闭，你没有办法保存它，因为你从来就没有服务端软件的副本，无论是源代码还是编译后的形式。
- 20世纪90年代，无法定制或扩展你所使用的软件的问题，在云软件中进一步加剧。对于在你自己的电脑上运行的闭源软件，至少有人可以对它的数据文件格式进行逆向工程，这样你还可以把它加载到其他的替代软件里（例如[OOXML](https://en.wikipedia.org/wiki/Office_Open_XML)之前的微软Office文件格式，或者[规范](https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/)发布前的Photoshop文件）。有了云软件，甚至连这个都做不到了，因为数据只存储在云端，而不是你自己电脑上的文件。

如果所有的软件都是免费和开源的，这些问题就都解决了。然而，开源实际上并不是解决云软件问题的必要条件；即使是闭源软件也可以避免上述问题，只要它运行在你自己的电脑上，而不是供应商的云服务器上。请注意，互联网档案馆能够在没有源代码的情况下维持历史软件的正常运行：如果只是出于存档的目的，在模拟器中运行编译后的机器代码就够了。也许拥有源码会让事情更容易一些，但这并不是不关键，最重要的事情，还是要有一份软件的副本。

## 本地优先的软件

我和我的合作者们以前曾主张过[本地优先软件](https://www.inkandswitch.com/local-first.html)的概念，这是对云软件的这些问题的一种回应。本地优先的软件在你自己的电脑上运行，将其数据存储在你的本地硬盘上，同时也保留了云计算软件的便利性，比如，实时协作，和在你所有的设备上同步数据。开源的本地优先的软件当然非常好，但这并不是必须的，本地优先软件90%的优点同样适用于闭源的软件。

云软件，而不是闭源软件，才是对软件自由的真正威胁，原因在于：云厂商能够突然心血来潮随心所欲地锁定你的所有数据，其危害要比无法查看和修改你的软件源码的危害大得多。因此，普及本地优先的软件显得更为重要和紧迫。如果在这一过程中，我们也能让更多的软件开放源代码，那也很不错，但这并没有那么关键。我们要聚焦在最重要与最紧迫的挑战上。

## 促进软件自由的法律工具

Copyleft软件许可证是一种法律工具，它试图迫使更多的软件供应商公开其源码。尤其是[AGPL](https://en.wikipedia.org/wiki/Affero_General_Public_License)，它尝试迫使云厂商发布其服务器端软件的源代码。然而这并没有什么用：大多数云厂商只是简单拒绝使用AGPL许可的软件：要么使用一个采用更宽松许可的替代实现版本，要么自己重新实现必要的功能，或者直接[购买一个没有版权限制的商业许可](https://www.elastic.co/pricing/faq/licensing)。有些代码无论如何都不会开放，我不认为这个许可证真的有让任何本来没开源的软件变开源。

作为一种促进软件自由的法律工具，我认为 copyleft 在很大程度上是失败的，因为它们在阻止云软件兴起上毫无建树，而且可能在促进开源软件份额增长上也没什么用。开源软件已经很成功了，但这种成功大部分都属于 non-copyleft 的项目（如Apache、MIT或BSD许可证），即使在GPL许可证的项目中（如Linux），我也怀疑版权方面是否真的是项目成功的重要因素。

对于促进软件自由而言，我相信更有前景的法律工具是政府监管。例如，GDPR提出了[数据可移植权](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/individual-rights/right-to-data-portability/)，这意味着用户必须可以能将他们的数据从一个服务转移到其它的服务中。现有的可移植性的实现，例如[谷歌Takeout](https://en.wikipedia.org/wiki/Google_Takeout)，是相当初级的（你真的能用一堆JSON压缩档案做点什么吗？），但我们可以游说监管机构[推动更好的可移植性/互操作性](https://interoperability.news/)，例如，要求相互竞争的两个供应商在它们的两个应用程序之间，实时双向同步你的数据。

另一条有希望的途径是，推动[公共部门的采购倾向于开源、本地优先的软件](https://joinup.ec.europa.eu/sites/default/files/document/2011-12/OSS-procurement-guideline -final.pdf)，而不是闭源的云软件。这为企业开发和维护高质量的开源软件创造了积极的激励机制，而版权条款却没有这样做。

你可能会争论说，软件许可证是开发者个人可以控制的东西，而政府监管和公共政策是一个更大的问题，不在任何一个个体权力范围之内。是的，但你选择一个软件许可证能产生多大的影响？任何不喜欢你的许可证的人可以简单地选择不使用你的软件，在这种情况下，你的力量是零。有效的改变来自于对大问题的集体行动，而不是来自于一个人的小开源项目选择一种许可证而不是另一种。



## GPL-家族许可证的其他问题

你可以强迫一家公司提供他们的GPL衍生软件项目的源码，但你不能强迫他们成为开源社区的好公民（例如，持续维护它们添加的功能特性、修复错误、帮助其他贡献者、提供良好的文档、参与项目管理）。如果它们没有真正参与开源项目，那么这些 "扔到你面前 "的源代码又有什么用？最好情况下，它没有价值；最坏的情况下，它还是有害的，因为它把维护的负担转嫁给了项目的其他贡献者。

我们需要人们成为优秀的开源社区贡献者，而这是通过保持开放欢迎的态度，建立正确的激励机制来实现的，而不是通过软件许可证。

最后，GPL许可证家族在实际使用中的一个问题是，它们[与其他广泛使用的许可证不兼容](http://gplv3.fsf.org/wiki/index.php/Compatible_licenses)，这使得在同一个项目中使用某些库的组合变得更为困难，且不必要地分裂了开源生态。如果GPL许可证有其他强大的优势，也许这个问题还值得忍受。但正如上面所述，我不认为这些优势存在。

## 结论

GPL和其他 copyleft 许可证并不坏，我只是认为它们毫无意义。它们有实际问题，而且被FSF的行为所玷污；但最重要的是，我不认为它们对软件自由做出了有效贡献。现在唯一真正在用 copyleft 的商业软件厂商（[MongoDB](https://www.mongodb.com/licensing/server-side-public-license/faq), [Elastic](https://www.elastic.co/pricing/faq/licensing)） —— 它们想阻止亚马逊将其软件作为服务提供，这当然很好，但这纯粹是出于商业上的考虑，而不是软件自由。

开源软件已经取得了巨大的成功，自由软件运动源于1990年代的反微软情绪，它已经走过了很长的路。我承认自由软件基金会对这一切的开始起到了重要作用。然而30年过去了，生态已经发生了变化，而自由软件基金会却没有跟上，而且[变得越来越不合群](https://r0ml.medium.com/free-software-an-idea-whose-time-has-passed-6570c1d8218a)。它没能对云软件和其他最近对软件自由的威胁做出清晰的回应，只是继续重复着几十年前的老论调。现在，通过恢复Stallman的地位和驳回对他的关注，FSF正在[积极地伤害](https://lu.is/blog/2021/04/07/values-centered-npos-with-kmaher/)自由软件的事业。我们必须与FSF和他们的世界观保持距离。

基于所有这些原因，我认为抓着GPL和 copyleft 已经没有意义了，放手吧。相反，我会鼓励你为你的项目采用一种宽容的许可协议（例如[MIT](https://opensource.org/licenses/MIT)， [BSD](https://opensource.org/licenses/BSD-2-Clause)， [Apache 2.0](https://opensource.org/licenses/Apache-2.0)），然后把你的精力放在真正能对软件自由产生影响的事情上。[抵制](https://www.inkandswitch.com/local-first.html)云软件的垄断效应，发展可持续的商业模式，让开源软件茁壮成长，并推动监管，将软件用户的利益置于供应商的利益之上。

* 感谢[Rob McQueen](https://ramcq.net/)对本帖草稿的反馈。



## 参考文献

1. RMS官复原职：(https://www.fsf.org/news/statement-of-fsf-board-on-election-of-richard-stallman
2. 自由软件基金会主页：https://www.fsf.org/
3. 弹劾RMS的公开信：https://rms-open-letter.github.io/
4. GNU项目声明：https://www.gnu.org/gnu/incorrect-quotation.en.html
5. GNU通用公共许可证 https://en.wikipedia.org/wiki/GNU_General_Public_License
6. copyleft: https://en.wikipedia.org/wiki/Copyleft
7. 衍生作品的定义：https://en.wikipedia.org/wiki/Derivative_work
8. x.ai被Bizzabo收购：https://ourincrediblejourney.tumblr.com/
9. Google Account Suspended No Reason Given：https://www.paullimitless.com/google-account-suspended-no-reason-given/
10. Google暂停用户账户：https://twitter.com/Demilogic/status/1358661840402845696
11. 互联网历史软件归档：https://archive.org/details/softwarelibrary
12. Office Open XML：https://en.wikipedia.org/wiki/Office_Open_XML
13. Photoshop File Formats Specification：https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
14. 本地优先软件：https://www.inkandswitch.com/local-first.html
15. AGPL协议：https://en.wikipedia.org/wiki/Affero_General_Public_License
16. Elastic商业许可证：https://www.elastic.co/cn/pricing/faq/licensing
17. 数据可移植权：https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/individual-rights/right-to-data-portability/
18. 谷歌Takeout（带走你的数据）：https://en.wikipedia.org/wiki/Google_Takeout
19. 互操作性新闻：https://interoperability.news/
20. 欧盟开源软件采购指南：https://joinup.ec.europa.eu/sites/default/files/document/2011-12/OSS-procurement-guideline%20-final.pdf
21. 许可证兼容性：https://gplv3.fsf.org/wiki/index.php/Compatible_licenses
22. MongoDB SSPL协议FAQ：https://gplv3.fsf.org/wiki/index.php/Compatible_licenses
23. Elastic许可变更问题汇总：https://gplv3.fsf.org/wiki/index.php/Compatible_licenses
24. “自由软件”：一个过时的想法：https://r0ml.medium.com/free-software-an-idea-whose-time-has-passed-6570c1d8218a
25. 一条FSF未曾设想的路：https://lu.is/blog/2021/04/07/values-centered-npos-with-kmaher/