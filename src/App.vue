<template>
	<v-app id="inspire">
    <v-navigation-drawer v-model="drawer" :clipped="$vuetify.breakpoint.lgAndUp" app temporary>
      <v-list>
        <v-list-item>
          <v-list-item-avatar>
            <v-img src="https://avatars3.githubusercontent.com/u/1269496?s=100&v=4"></v-img>
          </v-list-item-avatar>
        </v-list-item>
        <v-list-item link href="#/">
          <v-list-item-content>
            <v-list-item-title class="title">Wilson Wu</v-list-item-title>
            <v-list-item-subtitle>iwilsonwu@gmail.com</v-list-item-subtitle>
          </v-list-item-content>
        </v-list-item>
      </v-list>
      <v-divider></v-divider>
      <v-list>
        <v-list-group v-for="item in items" :key="item.title" v-model="item.active" no-action>
          <template v-slot:activator>
            <v-list-item-content>
              <v-list-item-title v-text="item.title"></v-list-item-title>
            </v-list-item-content>
          </template>
          <v-list-item v-for="subItem in item.items" :key="subItem.title" :href="subItem.url ? subItem.url : '#'">
            <v-list-item-content>
              <v-list-item-title v-text="subItem.title"></v-list-item-title>
            </v-list-item-content>
          </v-list-item>
          <v-divider></v-divider>

        </v-list-group>
      </v-list>
    </v-navigation-drawer>

    <v-app-bar :clipped-left="$vuetify.breakpoint.lgAndUp" app>
      <v-app-bar-nav-icon @click.stop="drawer = !drawer" />
      <v-toolbar-title style="width: 300px">
        <span class="hidden-sm-and-down">Wilson Wu OpenSource</span>
      </v-toolbar-title>
      <v-spacer />
      <v-btn icon @click="setTheme">
        <v-icon>mdi-theme-light-dark</v-icon>
      </v-btn>
    </v-app-bar>
    <v-content>
      <v-container fluid>
        <router-view></router-view>
      </v-container>
    </v-content>
    <v-footer app>
      <span>Wilson Wu &copy; 2009-2020</span>
    </v-footer>
  </v-app>
</template>

<script>
  export default {
    data: () => ({
      dark: null,
      drawer: null,
      items: [
        {
          key: 'vuetifyaudio',
          action: 'mdi-audiobook',
          title: 'vuetify-audio',
          active: false,
          items: [
            { title: 'Demo', url: '#/vuetifyaudio' },
            { title: 'Github', url: 'https://github.com/wilsonwu/vuetify-audio' }
          ]
        },
        /*{
          key: 'translationgoogle',
          action: 'mdi-audiobook',
          title: 'translation-google',
          active: false,
          items: [
            { title: 'Demo', url: '#/translationgoogle' },
            { title: 'Github', url: 'https://github.com/wilsonwu/translation-google' }
          ]
        },*/
        {
          key: 'setting',
          action: 'mdi-settings',
          title: 'About Wilson',
          active: false,
          items: [
            { title: 'Wilson Profile', url: 'http://wilsonwu.me' }
          ]
        }
      ],
    }),
    created () {
      this.dark = this.$vuetify.theme.dark
    },
    methods: {
      setTheme () {
        this.$vuetify.theme.dark = !this.dark   
        this.dark = !this.dark
      }
    },
  }
</script>
