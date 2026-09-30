<p align="center"><img src="../../Assets/AkkuLogo.png" width="160" alt="Akku, o macaco de bateria verde"></p>

# Akku

**Entenda sua bateria a partir da sua rotina.** Um companheiro nativo e experimental para MacBook Air e Pro com Apple Silicon M1–M5.

[English](../../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Português (Brasil)](README.pt-BR.md)

[Baixar](https://github.com/Francoocicchetti/Akku/releases) · [Feedback e ideias](https://github.com/Francoocicchetti/Akku/discussions) · [Relatar um problema](https://github.com/Francoocicchetti/Akku/issues/new/choose)

## Por que criei o Akku

Meu idioma nativo é o espanhol e não sou programador. Fiz o Akku com ajuda de ferramentas de IA porque queria cuidar melhor do meu MacBook e entender sua bateria: quanto dura com a minha rotina, onde costumo carregar e quando vale levar o carregador.

O projeto nasceu por preocupação com a saúde do meu próprio MacBook. Eu queria que a aplicação aprendesse com o dia a dia, sem exigir que eu descrevesse cada atividade. Akku também é o macaquinho que faz companhia: cheio de energia, com sono, com fome de eletricidade ou lembrando discretamente de uma pausa.

**Este é um projeto pessoal e experimental. Pode conter falhas, estimativas incorretas e comportamentos ainda incompletos.** Não afirmo ter experiência profissional em programação nem ter testado todos os MacBooks. Estou publicando para que outras pessoas possam experimentar, examinar o código e ajudar a melhorar. O app não conserta a bateria nem comprova que prolongará sua vida útil.

Como sou falante de espanhol, **algumas traduções podem estar estranhas ou erradas**, inclusive esta documentação. Correções são bem-vindas. Você pode deixar feedback em qualquer um dos seis idiomas disponíveis.

## Compatibilidade e idiomas

Esta versão se destina **somente ao MacBook Air e MacBook Pro com M1, M2, M3, M4 ou M5**, incluindo as variantes Pro/Max correspondentes. O teste físico foi feito em **um MacBook Air M5**. Reconhecer um modelo não significa validar todas as configurações.

Requer macOS 13 ou posterior, respeitando a versão mínima do próprio Mac. Versões anteriores compatíveis do macOS ainda precisam de testes físicos. Intel, Macs de mesa, MacBook Neo, Windows e Linux ficam fora do suporte atual. O script poder gerar uma parte Intel não representa uma promessa de suporte.

Uma instalação nova começa em inglês. Espanhol, francês, chinês simplificado, alemão e português do Brasil podem ser escolhidos no cabeçalho ou nos ajustes. A preferência é salva.

## Funcionalidades

### Uma carga completa, sua rotina

O Akku estima **quanto duraria a bateria de 100% a 0% com a combinação de usos observada nos últimos sete dias**. A tela inicial não exige escolher atividades ou informar uma duração manual.

Usa a queda real do percentual dividida pelo tempo observado na bateria com o Mac ativo. Carga, repouso e intervalos sem leituras são excluídos. Essa estimativa não desconta a reserva de segurança nem trata o percentual atual como uma carga completa.

A primeira previsão precisa de três dias observados, pelo menos dez minutos em cada um, noventa minutos no total e cinco pontos de bateria consumidos. Antes disso, mostra o progresso do aprendizado. Exibe um intervalo e confiança, ampliando a margem quando os dias variam. A confiança da rotina fica limitada a média até haver melhor calibração real. Outras tarefas, acessórios ou condições podem alterar o resultado.

### Registro automático e histórico

Desconectar o carregador inicia uma sessão. Abrir o Akku quando o Mac já está na bateria começa a observação naquele momento. Uma saída de casa confirmada também pode iniciar uma sessão. Não há botão para escanear ou começar. Carga otimizada pausada com o carregador conectado não é considerada desconexão.

Repouso e lacunas são excluídos; a observação continua ao despertar. Uma conexão estável por um minuto encerra a sessão. O Akku precisa estar aberto para aprender; iniciar com o login é opcional. Desativar o aprendizado pausa o registro.

As estatísticas mostram semana, sessões, pontos consumidos e tempo em casa, fora ou sem localização conhecida. O painel de bateria oferece **24 horas e 10 dias**, nível, períodos de carga/conexão, tela ligada observada e detalhes dos intervalos. Não inventa histórico ausente. Tela ligada não comprova atenção; os pontos podem passar de 100 após várias recargas.

### Apps reais e combinações

Informações nativas do macOS reconhecem Safari, FaceTime, ChatGPT, WhatsApp e outros apps abertos, com seus ícones. Tempo aberto e uso em primeiro plano ficam separados, com resumos por dia e lugar.

O Akku também observa o consumo do Mac inteiro enquanto combinações de apps estão abertas. **CPU não é energia exata por aplicativo.** FaceTime aberto não comprova uma chamada; um site dentro do Safari continua sendo Safari. Não lê mensagens, documentos, abas, conteúdo de tela ou teclas. Chamadas em segundo plano e leitura sem interação podem ser subestimadas.

### Lugares, mapa e volta para casa

O mapa interativo Apple MapKit mostra lugares frequentes, cargas observadas, episódios de bateria baixa e uso em 7 ou 30 dias. Selecionar um lugar mostra os apps e registros associados. Visitas repetidas podem sugerir casa ou trabalho; você confirma o significado.

A localização automática exige permissão do macOS e pode ser desativada. O aprendizado da bateria continua sem ela. É possível informar lugares ou a posição atual manualmente. A posição atual manual dura trinta minutos e nunca aparece como uma saída detectada automaticamente. A busca de endereço consulta o Apple Maps ao pressionar Buscar.

“Está saindo?” é um aviso discreto após uma mudança confirmada, não uma detecção instantânea. A distância de casa é **em linha reta, não uma rota nem tempo de viagem**. A orientação de carregar agora ou em casa combina bateria, reserva e os tempos de retorno/uso informados. Não garante chegar sem carregar. O Akku não substitui o Buscar nem localiza remotamente um computador desligado.

### Um companheiro animado

O macaco tem oito estados: pronto, cheio de energia, carregando, cansado, esgotado, pausa, noite e fora de casa. Alimentá-lo significa conectar o carregador real. As mensagens usam hora, bateria, uso recente e localização permitida, sem um serviço remoto de IA.

As animações começam ao aparecer ou mudar de estado e depois acontecem em sequências curtas. Pausam quando a interface está oculta, no Modo Pouca Energia, Emergência ou Reduzir Movimento. As sugestões de descanso ficam dentro do app e podem ser silenciadas; são aproximações, não monitoramento de saúde.

### Emergência e consumo do próprio app

O modo de emergência tenta reduzir o brilho em telas compatíveis, diminui as consultas do Akku, mostra as alterações e permite desfazer. Pouca Energia e sincronizações de outros apps exigem intervenção manual. Fechar um app pede confirmação e solicita encerramento normal, sem forçar; pode interromper chamadas ou uploads. Reabrir não recupera trabalho não salvo. Não há promessa de uma hora extra.

As observações ocorrem aproximadamente a cada minuto em segundo plano ou trinta segundos com a interface visível. O repouso interrompe o temporizador. Gravações são agrupadas, a CPU é consultada quando necessário e falhas de localização espaçam novas tentativas. As animações usam breves sequências de oito quadros por segundo. **Consumir pouco é uma meta de projeto, não consumo zero nem um resultado medido em todos os Macs.**

## Privacidade

Não há conta Akku, análise de uso externa ou servidor do desenvolvedor. O histórico fica em `~/Library/Application Support/BatteryTrip`; o nome antigo é mantido para preservar os dados. Os registros locais incluem bateria, identificadores e uso de apps, coordenadas de lugares e visitas agregadas, sem trajeto contínuo. Mapas, busca de endereço e localização do macOS podem se comunicar com a Apple.

Você pode apagar aprendizado e lugares. Exportações contêm observações de bateria e identificadores de apps, mas não coordenadas ou associações com lugares. **Revise e oculte dados pessoais antes de compartilhar.** Não publique endereço de casa, capturas de localização ou arquivos pessoais de uso.

## Instalação e compilação

Baixe o ZIP em [Releases](https://github.com/Francoocicchetti/Akku/releases), descompacte e mova `Akku.app` para Aplicativos. Encerre a cópia anterior antes de substituir. Preferências e histórico são preservados. Fechar a janela mantém o app na barra de menus; não execute duas versões juntas.

Esta prévia tem **assinatura local ad hoc, sem Developer ID ou notarização da Apple**. O macOS pode avisar ou impedir a abertura. O projeto não exige desativar a segurança do sistema. A assinatura para distribuição mais ampla ainda está pendente.

Para compilar: Mac, Python 3, Xcode/Command Line Tools, SDK compatível e Swift 5.9 ou superior. Não requer pacotes de terceiros.

```sh
./test.sh
./build.sh "$PWD/dist"
```

`notarize.sh` exige seu próprio certificado Developer ID e perfil do Acesso às Chaves; nenhuma credencial está incluída.

## Feedback e contribuições

Conte experiências, ideias e dúvidas em [Discussions](https://github.com/Francoocicchetti/Akku/discussions). Use os [formulários por idioma](https://github.com/Francoocicchetti/Akku/issues/new/choose) para falhas, consumo e correções de tradução. Informe modelo/chip, macOS, versão/idioma do Akku, passos, resultado esperado e real, carregador e Modo Pouca Energia. Para traduções, inclua tela, texto atual e sugestão. Os seis idiomas são bem-vindos, especialmente o espanhol.

[Feedback](../../FEEDBACK.md) · [Contribuições](../../CONTRIBUTING.md) · [Detalhes técnicos em inglês](../TECHNICAL.md) · [Validação em inglês](../VALIDATION.md) · [Mudanças](../../CHANGELOG.md). Testes automáticos não garantem precisão ou economia em todos os modelos. Ainda não foi escolhida uma licença de código aberto; este repositório não declara licença MIT, Apache ou equivalente.
