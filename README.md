# Azure Arc Jumpstart source code

Willkommen im Arc Jumpstart-Quellcode-Repository! Dieses Repository ist Ihre erste Anlaufstelle für die Arbeit mit den Automatisierungsskripten und -tools von Arc Jumpstart und dient als Backend-Quellcode-Repository, das unsere Website ergänzt.
Dokumentation: [documentation repository](https://github.com/Azure/arc_jumpstart_docs)
Arc Jumpstart: [Arc Jumpstart](https://aka.ms/arcjumpstart)

Die Bereitstellung erfolgt über diesen Button:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Faktapaz%2Fazure_arc%2Fbootcamp%2Fazure_jumpstart_arcbox%2Fbicep%2Fmain.json)

**Note:** Dieses Repository enthält nicht den Quellcode für die Dokumentation von Arc Jumpstart, der in einem anderen Repository zu finden ist  [dedicated repository](https://github.com/Azure/arc_jumpstart_docs).

## Was Sie hier finden werden

- **Automation Source Code:** Arc Jumpstart-Automatisierungsskripte und -Tools, die in unseren Szenarien und Lösungen verwendet werden.
- **Supportive Documents and Files:** Zusätzliche Ressourcen, die auf der gesamten  [Arc Jumpstart](https://aka.ms/ArcJumpstart) website genutzt werden, die in verschiedenen Zusammenhängen helfen und ergänzende Informationen liefern.

## Wie Sie dieses Repository nutzen können

Dieses Quellcode-Repository wurde für die Mitwirkenden entwickelt und arbeitet mit dem [our documentation repository](https://github.com/Azure/arc_jumpstart_docs). Es ist zwar nicht zwingend erforderlich, aber es ist höchstwahrscheinlich, dass Mitwirkende beide Repositories klonen sollten, um effektiv zu Arc Jumpstart beizutragen.

Bevor Sie beginnen, empfehlen wir Ihnen, sich mit unserem umfassenden [contribution guidelines](https://aka.ms/JumpstartContribution). In diesen Leitlinien werden die von uns befolgten Standards und Praktiken dargelegt, um die Konsistenz und Qualität unserer Dokumentation zu gewährleisten.

Wenn Sie sich unsicher sind, was Ihren künftigen Beitrag angeht, zögern Sie nicht, eine [GitHub discussion](https://aka.ms/JumpstartDiscussions). Dies ist ein großartiger Ort, um Fragen zu stellen, Ideen auszutauschen oder Feedback zu möglichen Beiträgen zu erhalten. Unsere Gemeinschaft ist da, um zu helfen, und wir begrüßen alle Erfahrungsstufen.

Viel Spaß beim Mitmachen!

## Klonen der Repositories

Um einen Beitrag zu leisten, müssen Sie wahrscheinlich sowohl dieses Repository als auch das [documentation repository](https://github.com/Azure/arc_jumpstart_docs) klonen. Verwenden Sie die folgenden Befehle:

```bash
git clone https://github.com/microsoft/azure_arc.git
git clone https://github.com/Azure/arc_jumpstart_docs.git
```

Da wir Arc Jumpstart ständig verbessern und erweitern, empfehlen wir Ihnen, Ihre lokalen Klone der Repositories auf dem neuesten Stand zu halten. Sie können dies tun, indem Sie die neuesten Änderungen aus dem Hauptbranch ziehen:

```bash
git pull origin main
```

Sie können Teilklone verwenden, wenn Sie die Zeit und den Umfang des Klonens dieses Repositorys reduzieren möchten. Wenn Sie dieses Repository klonen, erhalten Sie standardmäßig alle Dateien und die zugehörigen Metadaten, einschließlich Blobs und Diff-Historie. Wenn Sie jedoch nicht alle diese Informationen benötigen, können Sie den folgenden Befehl verwenden, um das Repository ohne die Blobs zu klonen:

```bash
git clone --filter=blob:none https://github.com/microsoft/azure_arc
```

## Beitrag und Feedback

Wir schätzen Ihren Beitrag! Wenn Sie Vorschläge, Feedback oder wertvolle Erkenntnisse mit uns teilen möchten, können Sie gerne ein Problem eröffnen. Ihre Beiträge helfen uns, die Dokumentation für die gesamte Gemeinschaft zu verbessern.

Dieses Projekt begrüßt Beiträge und Vorschläge.  Die meisten Beiträge erfordern die Zustimmung zu einer
Contributor License Agreement (CLA) zustimmen, in dem Sie erklären, dass Sie das Recht haben, uns die Rechte zur Nutzung Ihres Beitrags einzuräumen, und dies auch tatsächlich tun.Einzelheiten finden Sie auf der [Microsoft Contributor License Agreements website](https://cla.opensource.microsoft.com).

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).

Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
