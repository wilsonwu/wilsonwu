<template>
    <v-layout>
        <v-flex xs12 sm6 offset-sm3 lg4 offset-lg4>
			<v-card>
				<v-card-text>
					Base on vuetify-audio 0.2.1
				</v-card-text>
				<v-card-text>
					<vuetify-audio :file="file" :color="color" :ended="audioFinish"></vuetify-audio>
				</v-card-text>
				<v-card-actions>
					<v-btn outlined block @click="setColor">
						{{ btnText }}
					</v-btn>
				</v-card-actions>
				<v-card-text v-for="(msg,i) in msgs" :key="i">
					{{ msg }}
				</v-card-text>
				<v-card-text>
					This page source code: <a href="https://github.com/wilsonwu/wilsonwu/blob/master/src/views/VuetifyAudio.vue">Source Code</a>
				</v-card-text>
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
			color: null,
			btnText: 'Set Color to "Success" (Green)'
		}),
		methods: {
			audioFinish () {
				this.msgs.push('The audio finished.')
			},
			setColor () {
				if (this.color) {
					this.color = null
					this.btnText = 'Set Color to "Success" (Green)'
				} else {
					this.color = 'success'
					this.btnText = 'Set Color to Default (Follow the Theme)'
				}
			}
		},
	}
</script>