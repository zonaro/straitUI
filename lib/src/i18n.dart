import 'dart:ui';

class I18n {
  final String language;
  I18n(Locale locale) : language = ['pt', 'en', 'es'].contains(locale.languageCode) ? locale.languageCode : 'en';

  static const Map<String, Map<String, String>> strings = {
    'pt': {
      'sessions': 'Sessões', 'refresh': 'Atualizar', 'sources': 'Plataformas', 'search': 'Buscar conversas',
      'empty': 'Nenhuma conversa encontrada', 'select': 'Selecione uma conversa', 'selectHint': 'Escolha uma sessão para visualizar as mensagens.',
      'transfer': 'Copiar para', 'copy': 'Copiar comando', 'destination': 'Plataforma de destino', 'cancel': 'Cancelar',
      'confirm': 'Confirmar cópia', 'confirmHint': 'A sessão original será preservada. O Strait criará outra sessão no destino.',
      'loss': 'Alguns blocos (raciocínio/imagens) podem não ser transferidos.', 'go': 'Copiar conversa',
      'success': 'Conversa copiada', 'resume': 'Comando para retomar a sessão', 'close': 'Fechar',
      'loading': 'Carregando sessões...', 'offline': 'Strait não instalado', 'ready': 'Strait disponível',
      'all': 'Todas', 'messages': 'mensagens', 'tools': 'Ferramenta', 'result': 'Resultado',
      'thinking': 'Conteúdo privado omitido', 'image': 'Anexo/imagem não exibido',
      'error': 'Erro', 'noTarget': 'Habilite outra plataforma para copiar.', 'local': 'Dados locais',
      'notInstalled': 'Instale o Strait: npm install -g strait-cli', 'path': 'Projeto',
    },
    'en': {
      'sessions': 'Sessions', 'refresh': 'Refresh', 'sources': 'Providers', 'search': 'Search sessions',
      'empty': 'No sessions found', 'select': 'Select a session', 'selectHint': 'Choose a session to inspect its messages.',
      'transfer': 'Copy to', 'copy': 'Copy command', 'destination': 'Destination provider', 'cancel': 'Cancel',
      'confirm': 'Confirm copy', 'confirmHint': 'The original session is preserved. Strait creates a new session at the destination.',
      'loss': 'Some blocks (reasoning/images) may not survive conversion.', 'go': 'Copy conversation',
      'success': 'Session copied', 'resume': 'Resume command', 'close': 'Close',
      'loading': 'Loading sessions...', 'offline': 'Strait not installed', 'ready': 'Strait available',
      'all': 'All', 'messages': 'messages', 'tools': 'Tool', 'result': 'Result',
      'thinking': 'Private content omitted', 'image': 'Image/attachment not displayed',
      'error': 'Error', 'noTarget': 'Enable another provider to copy.', 'local': 'Local data',
      'notInstalled': 'Install Strait: npm install -g strait-cli', 'path': 'Project',
    },
    'es': {
      'sessions': 'Sesiones', 'refresh': 'Actualizar', 'sources': 'Plataformas', 'search': 'Buscar conversaciones',
      'empty': 'No se encontraron sesiones', 'select': 'Selecciona una sesión', 'selectHint': 'Selecciona una sesión para ver los mensajes.',
      'transfer': 'Copiar a', 'copy': 'Copiar comando', 'destination': 'Plataforma de destino', 'cancel': 'Cancelar',
      'confirm': 'Confirmar copia', 'confirmHint': 'Se conserva la sesión original. Strait creará una sesión nueva en el destino.',
      'loss': 'Algunos bloques (razonamiento/imágenes) pueden perderse.', 'go': 'Copiar conversación',
      'success': 'Sesión copiada', 'resume': 'Comando para continuar', 'close': 'Cerrar',
      'loading': 'Cargando sesiones...', 'offline': 'Strait no está instalado', 'ready': 'Strait disponible',
      'all': 'Todas', 'messages': 'mensajes', 'tools': 'Herramienta', 'result': 'Resultado',
      'thinking': 'Contenido privado omitido', 'image': 'Imagen/archivo no mostrado',
      'error': 'Error', 'noTarget': 'Activa otra plataforma para copiar.', 'local': 'Datos locales',
      'notInstalled': 'Instala Strait: npm install -g strait-cli', 'path': 'Proyecto',
    },
  };

  String t(String key) => strings[language]?[key] ?? strings['en']?[key] ?? key;
}
