<template>
    <v-layout>
        <v-flex xs12 sm6 offset-sm3 lg4 offset-lg4>
            <v-card>
				<v-card-text>
					Base on translation-google 0.2.1
				</v-card-text>
				<v-card-text>
                    <v-textarea
                    label="Original Text"
                    auto-grow
                    outlined
                    >{{ text }}</v-textarea>
				</v-card-text>
                <v-card-actions>
					<v-btn outlined block @click="doTranslate" large>
						Translate
					</v-btn>
				</v-card-actions>
                <v-card-text>
                <v-textarea
                    label="Translated Text"
                    auto-grow
                    outlined
                    disabled
                    >{{ result }}</v-textarea>
                </v-card-text>
				<v-card-text>
					This page source code: <a href="https://github.com/wilsonwu/wilsonwu/blob/master/src/views/TranslationGoogle.vue">Source Code</a>
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
        data: () => ({
			text: '',
			result: '',
		}),
		methods: {
			doTranslate () {
                //
			},
		},
    }
</script>
