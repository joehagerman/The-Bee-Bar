import AppKit

public enum BeeIcon {
    private static let base64Icon = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAJKADAAQAAAABAAAAJAAAAAAJxsHGAAAEAElEQVRYCe3WyW9NURzA8Ral5nlITEVVizYioUEiKoqEBQnRlSESC3asEP+AxEIkIgixETsbiRBzYmpDRMw1tcbWGKQ11/fLuy/3PU/67qshkv6ST94dzj3nd3/nnNtmZbXGf1aBthnk24Zn1NTMs5n0nRX1oXYk0R9D8BafkSo6crEAtm/EV6QVURPqQq/lWIH3qEU4qWzOO2EWVsI29/EBaYUdRI1cHsjHTJjQEbyDYcIzYAUP4w6sUNqRSUJB5304WIIGXI9dLOLXCu3B89i1SD/OcSbRnocGYQqmIQfGJ5zAUbzBR0SKqGvIzn3GSmxAGZyWSlTDnTceJnsNVqm53UiTloVTZTKum10ohbtKHu+G92xj2z8exYxwGlbGKUsOr3nPNraNFFHXkB/EHsiDO6wGfdEVht8mr9VjKGzrM2l/h6ImZPvOcBE7RW59B86HcRsm5D0Xvm19Ju3FnU5CLmLftDcGYzocsAhbYsfZ/BouYL87QRK2dec9wAu8xhf8MoKOUjXwe1IC14Q7pwAmZIdOl4ZhLB7BGIgruAc/jvKFTOgWLsK1dRl+v36KVBUySatRgbkwKZO4Cbe3H8Fq+ObrY79eM/rBdbQNTtlIWMlRmIoylOMA9sGqWdV4pErI6ZiHNcjBQVThKlwjfls6YD4KcQm+tdEdXvM7tB/H4NbPxxhMgH/nTNC/c3uRslJc/x5WZwTO4RnWYjhMLAhfohQOdgFL4NTJY6fFe7YJv7B92Nc62LdjOJZjxqNN/OjHgfPt2xXjLnbGfp2eIAZwsAgT8RROjdMqj5/Ae7axbRD2YZ87Yr+O4ViOGY/khMzWxeybuRZeIRzdOJmJBajDIdjGt5fHXvOebcrhM+GwzTs4hssjoUKcJ4QJFsFd8hB2GoQdL4X3XOSn4boYksRr3rONFVmKcFL2ad/ec6yEoiSUi5tNsLRWycVXgj5woS7EcrhWjA/wg+cCNQmNhlMxGb3g98vPwkDkYQ5WYTC24jBc3PFIVS4zzsNqVOArfMjyNuIW/C5dwwqYWDg6cLIdJncRBQiezeXY/vdhE2pg//FwHpPDBjbciONwgXZFHdzidr4ZVnEYTDIbhhX2fmdYaTeF98ehP1yXlaiC05aQDOcJ29LzIJz/WtTD9ZADq+RiLIXhoE5FgyehMFEZ7sLzOAMr9xmvkTBNnMcjVYXiNznwQTsNh2/5GL1hwmcRjkmcWCXbvIEVUlqRvKjTeci3dArLMAAmfQdO22wsQz524SiSK8il3xsO7FRtwDO8hFWSx17znm1s+1fCndITi3ESwbScil3znm0iR0vfIJcRC+F/BcYB3IDTmFG0NCEHdR0Gu8r18sWLrdFagX9VgW8vfuIn7U+HHwAAAABJRU5ErkJggg=="

    public static func createTemplateIcon() -> NSImage {
        // 1. Try loading from bundle resources
        if let bundleURL = Bundle.main.url(forResource: "BeeTemplate@2x", withExtension: "png") ?? Bundle.main.url(forResource: "BeeTemplate", withExtension: "png"),
           let img = NSImage(contentsOf: bundleURL) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            return img
        }

        // 2. Try loading from self-contained embedded base64 data
        if let data = Data(base64Encoded: base64Icon),
           let img = NSImage(data: data) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            return img
        }

        // 3. Fallback system symbol
        if let symbol = NSImage(systemSymbolName: "ant.fill", accessibilityDescription: "Bee") {
            symbol.isTemplate = true
            return symbol
        }

        return NSImage(size: NSSize(width: 18, height: 18))
    }
}
