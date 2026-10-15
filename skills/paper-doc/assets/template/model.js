/* Fictional reference model. Replace it with sourced facts for real documents. */
window.PAPER_DOC_MODELS = {
  example: {
    name: 'Report Service',
    description: 'Illustrative report-generation architecture for the paper-doc specimen.',
    status: 'Illustrative, not a deployed system',
    date: 'Example revision 1',
    initialView: 'context',
    tags: {
      core: { label: 'Core path', color: '#23477a' },
      async: { label: 'Background work', color: '#2f6b4f' },
      data: { label: 'Data', color: '#8a6200' },
    },
    elements: {
      analyst: { kind: 'person', name: 'Analyst', desc: 'Uploads source data and downloads completed reports.', tags: ['core'] },
      service: { kind: 'system', name: 'Report Service', desc: 'Turns an uploaded dataset into a downloadable report.', tags: ['core'], notes: { why: 'A single system boundary keeps the user journey clear.' } },
      mail: { kind: 'system', external: true, name: 'Mail Provider', tech: 'HTTPS API', desc: 'Delivers completion notifications.', tags: ['async'] },
      telemetry: { kind: 'system', external: true, supporting: true, name: 'Telemetry', tech: 'OTLP', desc: 'Receives operational traces and metrics.', tags: ['async'] },
      browser: { kind: 'app', parent: 'service', name: 'Browser App', tech: 'HTML / JavaScript', desc: 'Uploads datasets and reads job status.', tags: ['core'] },
      api: { kind: 'app', parent: 'service', name: 'Report API', tech: 'HTTP / JSON', desc: 'Validates requests and records queued jobs.', tags: ['core', 'data'], notes: { tradeoff: 'The client polls status instead of maintaining a realtime channel.' } },
      worker: { kind: 'app', parent: 'service', name: 'Report Worker', tech: 'Background process', desc: 'Claims jobs, renders reports, and sends completion notifications.', tags: ['async'], notes: { why: 'Long-running work is independent of the HTTP request.', improve: 'A real design must specify claim expiry and safe retries.' } },
      database: { kind: 'store', parent: 'service', name: 'Job Database', tech: 'PostgreSQL', desc: 'Stores job status, source data, and report records.', tags: ['data', 'async'] },
      claim: { kind: 'component', parent: 'worker', name: 'Job Claimer', tech: 'SQL', desc: 'Claims a queued job for one worker.', tags: ['async', 'data'] },
      renderer: { kind: 'component', parent: 'worker', name: 'Report Renderer', tech: 'Application code', desc: 'Converts the source data into the final report.', tags: ['async'] },
      notifier: { kind: 'component', parent: 'worker', name: 'Completion Notifier', tech: 'HTTPS client', desc: 'Requests an email after a report is stored.', tags: ['async'] },
    },
    rels: [
      { from: 'analyst', to: 'service', label: 'Submits data and retrieves reports', tech: 'HTTPS', only: ['context'] },
      { from: 'analyst', to: 'browser', label: 'Uploads data and views status', tech: 'HTTPS', only: ['containers'] },
      { from: 'browser', to: 'api', label: 'Creates jobs and polls status', tech: 'HTTPS / JSON' },
      { from: 'api', to: 'database', label: 'Stores job and source data', tech: 'SQL / TLS' },
      { from: 'claim', to: 'database', label: 'Claims queued jobs', tech: 'SQL / TLS', async: true },
      { from: 'claim', to: 'renderer', label: 'Passes the claimed job', tech: 'In-process call' },
      { from: 'renderer', to: 'database', label: 'Stores report and completion', tech: 'SQL / TLS' },
      { from: 'renderer', to: 'notifier', label: 'Requests a notification', tech: 'In-process call' },
      { from: 'notifier', to: 'mail', label: 'Sends completion email', tech: 'HTTPS', async: true },
      { from: 'worker', to: 'telemetry', label: 'Emits traces and metrics', tech: 'OTLP / HTTPS', async: true },
    ],
    views: {
      context: {
        level: 1, scope: 'service', title: 'System context', ipTitle: 'System context', crumb: 'Context',
        layout: { analyst: [0, 160], service: [400, 160], mail: [900, 160], telemetry: [900, 460, 'sm'] },
        drill: { service: 'containers' }, labelT: { 'analyst>service': .5, 'service>mail': .5 },
      },
      containers: {
        level: 2, scope: 'service', title: 'Containers', ipTitle: 'Apps and stores', crumb: 'Containers', parent: 'context',
        layout: { analyst: [-350, 100], browser: [0, 100], api: [400, 100], database: [400, 450], worker: [850, 450], mail: [1250, 450], telemetry: [1250, 100, 'sm'] },
        drill: { worker: 'worker_components' }, labels: 'select',
        curves: { 'worker>telemetry': 80 },
      },
      worker_components: {
        level: 3, scope: 'worker', title: 'Worker components', ipTitle: 'Worker components', crumb: 'Worker', parent: 'containers',
        layout: { claim: [0, 100], renderer: [400, 100], notifier: [800, 100], database: [200, 470], mail: [1200, 100] },
        curves: { 'claim>database': 45, 'renderer>database': -45 },
      },
    },
    flows: [
      {
        id: 'generate_report', name: 'Generate a report', view: 'containers',
        steps: [
          { from: 'browser', to: 'api', text: 'The browser submits the source dataset and asks for a report.' },
          { from: 'api', to: 'database', text: 'The API persists a queued job and returns its identifier.' },
          { from: 'claim', to: 'database', text: 'The worker claims the queued job from the database.' },
          { view: 'worker_components', from: 'claim', to: 'renderer', text: 'Inside the worker, the claimer hands the job to the renderer.' },
          { view: 'worker_components', from: 'renderer', to: 'database', text: 'The renderer saves the report and marks the job complete.' },
          { view: 'worker_components', from: 'renderer', to: 'notifier', text: 'The renderer requests a completion notification.' },
          { view: 'worker_components', from: 'notifier', to: 'mail', text: 'The notifier asks the mail provider to deliver the completion email.' },
        ],
      },
    ],
  },
};
