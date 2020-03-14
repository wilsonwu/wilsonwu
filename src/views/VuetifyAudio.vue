<template>
    <v-layout>
        <v-flex xs12 sm6 offset-sm3 lg4 offset-lg4>
			<v-card>
				<v-card-text>
					Base on vuetify-audio 0.2.1
				</v-card-text>
			</v-card>
			<vuetify-audio :file="file" color="success" :ended="audioFinish"></vuetify-audio>
			<v-card>
				<v-card-text v-for="(msg,i) in msgs" :key="i">
					{{ msg }}
				</v-card-text>
			</v-card>
			<v-card>
				<v-card-text>
					This page source code: <a href="https://github.com/wilsonwu/wilsonwu.github.io/blob/master/src/views/VuetifyAudio.vue">Source Code</a>
				</v-card-text>
			</v-card>
			<v-card>
				<v-card-text>
					The component source code: <a href="https://github.com/wilsonwu/vuetify-audio/">wilsonwu/vuetify-audio</a>
				</v-card-text>
			</v-card>
		</v-flex>
	</v-layout>
</template>
<script>

	export default {
		components: {
			VuetifyAudio: () => import('vuetify-audio'),
		},
		data: () => ({
			file: 'http://www.noiseaddicts.com/samples_1w72b820/290.mp3',
		}),
		methods: {
			audioFinish () {
				this.msgs.push('The audio finished.');
			},
		},
	}
</script>