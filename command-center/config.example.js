// Template for the command centre's runtime config.
//
// Setup: copy this file to config.js in the same folder and fill in
// your Supabase project's URL and publishable (anon) key, both from
// Dashboard -> Project Settings -> API. config.js is gitignored, so
// the keys stay on the machine that runs the console.
//
// The publishable key is safe in a browser by design — row-level
// security on the server decides what each signed-in user may read.
// Never put the service_role key here: it bypasses RLS entirely.
window.H2R_CONFIG = {
  supabaseUrl: 'https://YOUR-PROJECT-REF.supabase.co',
  supabaseKey: 'sb_publishable_YOUR_KEY_HERE',
};
