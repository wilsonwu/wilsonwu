import Home from './views/Home.vue'
import VuetifyAudio from './views/VuetifyAudio.vue'
import TranslationGoogle from './views/TranslationGoogle.vue'
import NotFound from './views/404.vue'

const routes = [
  { path: '/', component: Home },
  { path: '/vuetifyaudio', component: VuetifyAudio },
  { path: '/translationgoogle', component: TranslationGoogle },
  {	path: '*', component: NotFound }
];

export default routes;
