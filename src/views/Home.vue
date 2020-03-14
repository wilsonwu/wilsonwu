<template>
    <div>
        This is home page, currently is empty.
    </div>
</template>
<script>
  export default {
    computed: {
        username() {
        // 我们很快就会看到 `params` 是什么
        return this.$route.params.username
        }
    },
    methods: {
        goBack() {
        window.history.length > 1 ? this.$router.go(-1) : this.$router.push('/')
        }
    }
  }
</script>

