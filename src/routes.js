import Home from './views/Home.vue'
import VuetifyAudio from './views/VuetifyAudio.vue'
import NotFound from './views/404.vue'

const routes = [
  { path: '/', component: Home },
  { path: '/vuetifyaudio', component: VuetifyAudio },
  {	path: '*', component: NotFound }
];

export default routes;
